"""
A tunneling proxy for EVD.

Reference implementation.
"""

import base64
import json
import asyncore
import sys
import socket
import logging

log = logging.getLogger(__name__)


class DispatcherBase(asyncore.dispatcher):
    def __init__(self, protocol):
        asyncore.dispatcher.__init__(self)
        self.build_socket(protocol)

    def build_socket(self, protocol):
        if protocol == 'tcp':
            self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
        else:
            self.create_socket(socket.AF_INET, socket.SOCK_DGRAM)


class TunnelBind(DispatcherBase):
    RECV_MAX = 8192

    class Handler(asyncore.dispatcher_with_send):
        RECV_MAX = 8192

        def __init__(self, server, sock, addr):
            asyncore.dispatcher_with_send.__init__(self, sock)
            self.server = server
            self.addr = addr

        def handle_close(self):
            log.info("%s: closed" % repr(self.addr), exc_info=sys.exc_info())
            self.server.remove_client(self.addr)
            self.close()

        def handle_error(self):
            log.info("%s: error" % repr(self.addr), exc_info=sys.exc_info())
            self.server.remove_client(self.addr)
            self.close()

        def handle_read(self):
            data = self.recv(self.RECV_MAX)
            self.server.receive_data(data)

    def __init__(self, tunnel, protocol, port):
        DispatcherBase.__init__(self, protocol)
        self._tunnel = tunnel
        self._protocol = protocol
        self._port = port
        self._clients = dict()

    def handle_read(self):
        """If this is an UDP"""
        data, addr = self.recvfrom(self.RECV_MAX)
        self._tunnel.receive_client_data(self._protocol, self._port, data)

    def receive_data(self, data):
        """Receive data from client connected over TCP."""
        self._tunnel.receive_client_data(self._protocol, self._port, data)

    def handle_close(self):
        for addr, client in self._clients.items():
            client.close()

        self.close()

    def handle_accept(self):
        pair = self.accept()

        if pair is None:
            return

        sock, addr = pair
        handler = self.Handler(self, sock, addr)
        self._clients[addr] = handler

    def remove_client(self, addr):
        try:
            del self._clients[addr]
        except KeyError:
            pass



class SimpleDispatcher(DispatcherBase):
    RECV_MAX = 8192

    def __init__(self, client_impl, protocol='tcp', args=[]):
        DispatcherBase.__init__(self, protocol)
        self._buffer = []
        self._buffer_size = 0
        self._client_impl = client_impl
        self._args = args
        self._client = None

    def build_socket(self, protocol):
        if protocol == 'tcp':
            self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
        else:
            self.create_socket(socket.AF_INET, socket.SOCK_DGRAM)

    def handle_connect(self):
        try:
            self._client = self._client_impl(self, *self._args)
        except:
            log.error("failed to make client", exc_info=sys.exc_info())
            self.handle_error()

    def handle_error(self):
        exc_info = sys.exc_info()
        t, exc, tb = exc_info
        log.error("error: %s", str(exc), exc_info=exc_info)
        self.close()

    def handle_close(self):
        log.info("closed")
        self.close()

    def handle_read(self):
        data = self.recv(self.RECV_MAX)
        self._client.receive_data(data)

    def writable(self):
        return not self._client or self._buffer_size > 0

    def handle_write(self):
        if self._buffer_size <= 0:
            return

        buf = "".join(self._buffer)
        sent = self.send(buf)
        new_buf = buf[sent:]
        self._buffer = [new_buf]
        self._buffer_size = len(new_buf)

    def send_data(self, data):
        self._buffer.append(data)
        self._buffer_size += len(data)


class LineReceiver(object):
    def __init__(self, dispatcher):
        self._buffer = list()
        self.dispatcher = dispatcher

    def receive_data(self, data):
        """
        Implement to receive data.
        """

        while data:
            i = 0

            for i, c in enumerate(data):
                if c != '\n':
                    continue

                line = "".join(self._buffer) + data[:i]

                try:
                    self.receive_line(line)
                except:
                    log.error("receive line failed", exc_info=sys.exc_info())

                self._buffer = []
                data = data[i + 1:]
                break

            if i == len(data):
                self._buffer.append(data)
                break

    def receive_line(self, line):
        pass

    def send_line(self, line):
        self.dispatcher.send_data(line + "\n")


class TunnelClient(LineReceiver):
    """
    Implement the tunneling protocol.
    """
    def __init__(self, dispatcher, metadata):
        LineReceiver.__init__(self, dispatcher)
        self.metadata = metadata
        self.send_line(json.dumps(self.metadata))
        self.config = None
        self.servers = list()

    def receive_line(self, line):
        """
        Implement to receive data.
        """

        if self.config is None:
            self.config = json.loads(line)
            self.bind_socket()
            return

    def receive_client_data(self, protocol, port, data):
        data = base64.b64encode(data)
        self.send_line("%s %s %s" % (protocol, port, data))

    def bind_socket(self):
        log.info("Config: %s" % (repr(self.config)))

        bind = self.config.get('bind', [])

        for b in bind:
            protocol = b['protocol']
            port = b['port']

            server = TunnelBind(self, protocol, port)

            try:
                server.bind(('127.0.0.1', port))
            except:
                log.error("failed to bind: %s" % (repr(b)),
                          exc_info=sys.exc_info())
                continue

            server.set_reuse_addr()

            if protocol == "tcp":
                server.listen(5)

            self.servers.append(server)

        if len(self.servers) != len(bind):
            log.error("could not bind all servers: %s" % (repr(bind)))

            for server in self.servers:
                server.close()

            self.dispatcher.close()


def main(args):
    logging.basicConfig(level=logging.INFO)

    metadata = dict(host="hello")
    client = SimpleDispatcher(TunnelClient, args=[metadata])
    client.connect(('127.0.0.1', 9000))
    asyncore.loop()

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

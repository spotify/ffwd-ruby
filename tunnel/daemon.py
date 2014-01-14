"""
A tunneling proxy for EVD.
"""

import json
import time
import asyncore
import sys
import socket
import heapq
import logging

log = logging.getLogger(__name__)

tasks = []


def set_timeout(t, task):
    global tasks
    when = time.time() + t
    heapq.heappush(tasks, (when, task))


class ReconnectingDispatcher(asyncore.dispatcher):
    MAX_RECV = 8192

    def __init__(self, client_impl, host='127.0.0.1', port=5000,
                 reconnect_timeout=10.0, args=[]):
        asyncore.dispatcher.__init__(self)
        self._client_impl = client_impl
        self.peer = (host, port)
        self._buffer = []
        self._buffer_size = 0
        self._running = False
        self._reconnect = reconnect_timeout
        self._client = None
        self._args = args

    def _connect(self):
        self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
        self.connect(self.peer)

    def start(self):
        self._running = True
        self._connect()

    def stop(self):
        self._running = False
        self.close()

    def reconnect(self):
        if not self._running:
            return

        self._connect()

    def handle_connect(self):
        try:
            self._client = self._client_impl(self, *self._args)
        except:
            log.error("failed to make client", exc_info=sys.exc_info())
            self.handle_error()

    def handle_error(self):
        exc_info = sys.exc_info()
        t, exc, tb = exc_info
        log.error("reconnect in %ds: %s", self._reconnect, str(exc), exc_info=exc_info)
        set_timeout(self._reconnect, self.reconnect)
        self.close()

    def handle_close(self):
        log.info("reconnect in %ds: closed", self._reconnect)
        set_timeout(self._reconnect, self.reconnect)
        self.close()

    def handle_read(self):
        data = self.recv(self.MAX_RECV)
        self._client.receive_data(data)

    def writable(self):
        return self._buffer_size > 0

    def handle_write(self):
        buf = "".join(self._buffer)
        sent = self.send(buf)
        new_buf = buf[sent:]
        self._buffer = [new_buf]
        self._buffer_size = len(new_buf)

    def send_data(self, data):
        self._buffer.append(data)
        self._buffer_size += len(data)


class Client(asyncore.dispatcher_with_send):
    MAX_RECV = 8192

    def handle_read(self):
        print self.recv(self.MAX_RECV)


def run_tasks():
    global tasks

    timeout = None
    task = None

    while len(tasks) > 0:
        when, task = heapq.heappop(tasks)
        timeout = when - time.time()

        if timeout <= 0:
            try:
                task()
            except Exception, e:
                print "Error when executing task:", str(e)

            timeout = None
            continue

        heapq.heappush(tasks, (when, task))
        break

    return timeout


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

    def receive_line(self, line):
        """
        Implement to receive data.
        """

        if self.config is None:
            self.config = json.loads(line)
            return

        print repr(line)


def main(args):
    metadata = dict(host="hello")
    client = ReconnectingDispatcher(TunnelClient, args=[metadata])
    client.start()

    logging.basicConfig(level=logging.INFO)

    while True:
        timeout = run_tasks()

        if not asyncore.socket_map:
            if timeout is None:
                raise Exception("Nothing to do, this is a bug")

            time.sleep(timeout)
            continue

        asyncore.loop(timeout=timeout, count=1)

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

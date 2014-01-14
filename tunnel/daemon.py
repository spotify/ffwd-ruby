"""
A tunneling proxy for EVD.
"""

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

    def __init__(self, client_impl, host, port, reconnect_timeout=10.0):
        asyncore.dispatcher.__init__(self)
        self._client_impl = client_impl
        self.peer = (host, port)
        self._buffer = []
        self._buffer_size = 0
        self._running = False
        self._reconnect = reconnect_timeout
        self._client = None

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
        self._client = self._client_impl(self)

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


class TunnelClient(object):
    """
    Implement the tunneling protocol.
    """
    def __init__(self, dispatcher):
        self.dispatcher = dispatcher

    def receive_data(self, data):
        """
        Implement to receive data.
        """
        print data


def main(args):
    client = ReconnectingDispatcher(TunnelClient, '127.0.0.1', 5000)
    client.start()

    logging.basicConfig(level=logging.INFO)

    while True:
        timeout = run_tasks()

        if not asyncore.socket_map:
            time.sleep(timeout)
            continue

        asyncore.loop(timeout=timeout, count=1)

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

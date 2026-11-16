"""Single-client UDP LAN relay with independent one-way delay, jitter and loss."""

import argparse
import heapq
import random
import select
import socket
import threading
import time


class Relay:
    def __init__(self, listen, host, delay_ms, jitter_ms, loss, seed=0):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(listen)
        self.sock.setblocking(False)
        self.host = (socket.gethostbyname(host[0]), host[1])
        self.client = None
        self.delay = delay_ms / 1000
        self.jitter = jitter_ms / 1000
        self.loss = loss
        self.rng = random.Random(seed)
        self.pending = []
        self.sequence = 0
        self.received = self.dropped = self.forwarded = 0

    def run(self, stop):
        try:
            while not stop.is_set():
                now = time.perf_counter()
                while self.pending and self.pending[0][0] <= now:
                    _, _, data, destination = heapq.heappop(self.pending)
                    self.sock.sendto(data, destination)
                    self.forwarded += 1
                timeout = min(0.05, max(0, self.pending[0][0] - now)) if self.pending else 0.05
                if not select.select([self.sock], [], [], timeout)[0]:
                    continue
                try:
                    data, sender = self.sock.recvfrom(65535)
                except ConnectionResetError:
                    # Windows reports ICMP from a closed peer on the next UDP read.
                    continue
                if sender == self.host:
                    destination = self.client
                else:
                    # A reconnect can use a new ephemeral client port.
                    self.client = sender
                    destination = self.host
                if destination is None:
                    continue
                self.received += 1
                if self.rng.random() < self.loss:
                    self.dropped += 1
                    continue
                self.sequence += 1
                due = time.perf_counter() + max(0, self.delay + self.rng.uniform(-self.jitter, self.jitter))
                heapq.heappush(self.pending, (due, self.sequence, data, destination))
        finally:
            self.sock.close()


def self_test():
    """Exercise actual UDP in both directions, a new client port, and total loss."""
    host = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    host.bind(("127.0.0.1", 0))
    host.settimeout(1)
    relay = Relay(("127.0.0.1", 0), host.getsockname(), 20, 0, 0)
    address = relay.sock.getsockname()
    stop = threading.Event()
    thread = threading.Thread(target=relay.run, args=(stop,))
    thread.start()
    try:
        for payload in [b"first client", b"rejoined client"]:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
                client.settimeout(1)
                start = time.monotonic()
                client.sendto(payload, address)
                data, sender = host.recvfrom(65535)
                assert data == payload
                host.sendto(data, sender)
                assert client.recvfrom(65535)[0] == payload
                assert time.monotonic() - start >= 0.035
            host.sendto(b"late packet to closed client", sender)
            time.sleep(0.05)
        relay.loss = 1
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
            client.sendto(b"drop", address)
            host.settimeout(0.15)
            try:
                host.recvfrom(65535)
            except socket.timeout:
                pass
            else:
                raise AssertionError("100% loss forwarded a packet")
        assert relay.dropped == 1 and relay.forwarded == 6
    finally:
        stop.set()
        thread.join(timeout=2)
        host.close()
    print("UDP RELAY SELF-TEST: delay, two-way delivery, rejoin, loss PASS")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--listen-address", default="127.0.0.1")
    parser.add_argument("--listen-port", type=int, default=7778)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--host-port", type=int, default=7777)
    parser.add_argument("--delay-ms", type=float, default=0)
    parser.add_argument("--jitter-ms", type=float, default=0)
    parser.add_argument("--loss", type=float, default=0)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if not 0 <= args.loss <= 1 or not 0 <= args.delay_ms < float("inf") or not 0 <= args.jitter_ms < float("inf"):
        parser.error("delay/jitter must be finite and nonnegative; loss must be in [0, 1]")
    if not 1 <= args.listen_port <= 65535 or not 1 <= args.host_port <= 65535:
        parser.error("ports must be in [1, 65535]")
    relay = Relay((args.listen_address, args.listen_port), (args.host, args.host_port), args.delay_ms, args.jitter_ms, args.loss, args.seed)
    print(f"UDP relay {relay.sock.getsockname()} -> {relay.host}; delay={args.delay_ms}ms jitter={args.jitter_ms}ms loss={args.loss}", flush=True)
    try:
        relay.run(threading.Event())
    except KeyboardInterrupt:
        pass
    finally:
        print(f"received={relay.received} forwarded={relay.forwarded} dropped={relay.dropped}", flush=True)


if __name__ == "__main__":
    main()

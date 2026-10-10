#!/usr/bin/env python3
"""Bidirectional mDNS reflector between the Mac's LAN interface and the OrbStack
vmnet bridge, so Bonjour services advertised by pods running with hostNetwork inside
the k3s VM (e.g. Home Assistant HomeKit bridge) are visible on the LAN.

Usage: mdns-reflector.py LAN_IP VM_IP LAN_CIDR VM_CIDR
  e.g. mdns-reflector.py 192.168.88.2 192.168.139.3 192.168.88.0/24 192.168.138.0/23

Loop prevention: reflected packets leave with the Mac's own IP as source, and packets
from the Mac's own IPs are never reflected. Questions are forwarded with the
unicast-response (QU) bit cleared so answers come back via multicast.
"""
import ipaddress
import select
import socket
import struct
import sys
import time

GROUP = "224.0.0.251"
PORT = 5353


def open_socket(ifip):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)  # share 5353 with mDNSResponder
    s.bind(("", PORT))
    s.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP,
                 socket.inet_aton(GROUP) + socket.inet_aton(ifip))
    s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_IF, socket.inet_aton(ifip))
    s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 255)
    s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_LOOP, 0)
    return s


def clear_qu(p):
    """Clear the unicast-response bit on every question of a query packet."""
    try:
        if len(p) < 12 or p[2] & 0x80:  # too short, or a response: leave untouched
            return p
        b = bytearray(p)
        i = 12
        for _ in range(struct.unpack("!H", p[4:6])[0]):
            while True:
                n = b[i]
                if n == 0:
                    i += 1
                    break
                if n & 0xC0 == 0xC0:
                    i += 2
                    break
                i += 1 + n
            b[i + 2] &= 0x7F
            i += 4
        return bytes(b)
    except IndexError:
        return p


def run(lan_ip, vm_ip, lan_net, vm_net):
    own = {lan_ip, vm_ip}
    lan, vm = open_socket(lan_ip), open_socket(vm_ip)
    stats = {"lan->vm": 0, "vm->lan": 0}
    last = time.time()
    print(f"reflecting {lan_ip} <-> {vm_ip}", flush=True)
    while True:
        for s in select.select([lan, vm], [], [], 5)[0]:
            data, (src, _) = s.recvfrom(9000)
            if src in own:
                continue
            addr = ipaddress.ip_address(src)
            if addr in vm_net:
                out, key = lan, "vm->lan"
            elif addr in lan_net:
                out, key = vm, "lan->vm"
                data = clear_qu(data)
            else:
                continue
            out.sendto(data, (GROUP, PORT))
            stats[key] += 1
        if time.time() - last > 3600:
            print(stats, flush=True)
            last = time.time()


if __name__ == "__main__":
    lan_ip, vm_ip = sys.argv[1], sys.argv[2]
    nets = (ipaddress.ip_network(sys.argv[3]), ipaddress.ip_network(sys.argv[4]))
    while True:  # the vmnet bridge only exists once OrbStack is up
        try:
            run(lan_ip, vm_ip, *nets)
        except OSError as e:
            print(f"error: {e}; retrying in 10s", flush=True)
            time.sleep(10)

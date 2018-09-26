NFQUEUE Example
====

```
                 +--------------------------------------+
                 |      localhost:8085 ===              |
                 |         A            |               |
                 |    localhost:8054    | Internal      |
                 |      A  |            |   DNS Servers |
                 |      |  |            |               |
                 |  localhost:8053     ===              |
                 |   A  |  |                            |
                 |   |  |  | balancing                  |
                 |   |  |  |                            |
                 |   |  |  |                            |
                 |  +---------+                         |         +----------------> 8.8.8.8 ====
                 |  |         |    balancing            |         |                           |
                 |  | brahman |-------------------------|-------- |----------------> 8.8.4.4  | External DNS servers
                 |  |         |                         |         |                           |
                 |  +---------+                         |         +----------------> 1.1.1.1 ====
                 |    A     | NFQUEUE verdict = accept  |
                 |    |     |                           |
                 |    | NFQUEUE call                    |
                 |    |     |                           |
                 |    |     v                           |
                 | +--------------+                     |
DNS packet------>| | iptables     |                     |
                 | +--------------+                     |
                 +--------------------------------------+
```

```shellsession
> $ dig -p8054 @127.0.0.1 example.com

; <<>> DiG 9.11.3-1ubuntu1.2-Ubuntu <<>> -p8054 @127.0.0.1 example.com
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 1152
;; flags: qr aa rd; QUERY: 1, ANSWER: 3, AUTHORITY: 0, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
; COOKIE: fcae345361867163 (echoed)
;; QUESTION SECTION:
;example.com.                   IN      A

;; ANSWER SECTION:
dummy1.example.com.     3600    IN      A       192.168.5.1
dummy2.example.com.     3600    IN      A       192.168.5.2
dummy3.example.com.     3600    IN      A       192.168.5.3

;; Query time: 4 msec
;; SERVER: 127.0.0.1#8054(127.0.0.1)
;; WHEN: Thu Sep 27 01:22:37 JST 2018
;; MSG SIZE  rcvd: 121
```

very simple implementation but this example is slow.

```
Statistics:

  Queries sent:         14817
  Queries completed:    12976 (87.58%)
  Queries lost:         1841 (12.42%)

  Response codes:       NOERROR 12976 (100.00%)
  Average packet size:  request 29, response 98
  Run time (s):         10.158811
  Queries per second:   1277.314835

  Average Latency (s):  0.068880 (min 0.000638, max 0.425337)
  Latency StdDev (s):   0.073219
```

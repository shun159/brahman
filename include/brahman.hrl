-record(tracking,
        {
         total_successes = 0,
         total_failures = 0,
         consecutive_failures = 0,
         max_failure_threshold = 5,
         last_failure_time = 0,
         failure_backoff =  10000 * 1.0e6
        }).

-record(ewma,
        {
         cost = 0,
         stamp = erlang:monotonic_time(nano_seconds),
         penalty = 1.0e307,
         pending = 0,
         decay = 10.0e9
        }).

-record(upstream,
        {
         ip_port,
         tracking = #tracking{},
         ewma = #ewma{}
        }).

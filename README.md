#Marathon-lb vhost check

`carton exec "perl marathon_lb_vhost_test.pl -v --marathon http://marathon.host --lb lb1.host --lb lb2.host"`
or
`docker run avastsoftware/marathon_lb_vhost_test -v --marathon http://marathon.host --lb lb1.host --lb lb2.host`

example result:
```
Found 3 apps in marathon
#/app1 - not instances
#/app2 - no vhost set
/app3
	app3.host
		status 200: 100x
	app3.host (lb1.host)
		status 200: 100x
	app3.host (lb2.host)
		status 200: 100x
	mesos-slave.host:31643
		status 200: 100x
```

This script is usefully if you try find/test some problem with you mesos/marathon/marathon-lb infrastructure.

This script load all apps from marathon, finding HAPROXY_\d+_VHOST label and try send simple GET request to this endpoint.
Try too direct GET request to host:port of instances of this app.
If you set lb option, then script do GET request via this `lb` points as `vhost` name (like `curl --resolve vhost:80:lb vhost`).

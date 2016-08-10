# go-whosonfirst-pip

An in-memory point-in-polygon (reverse geocoding) package for Who's On First data

## Set up

The easiest way to install all the dependencies and compile all of the code and command line tools is to use the handy Makefile that is included with this repository, like this:

```
make build
```

In addition to clone all the vendored dependencies (stored in the [vendor](vendor) directory along with the `go-whosonfirst-pip` packages in to the `src` directory (along with all the dependencies) which is a thing you need to do because of the way Go expects code to organized. It's kind of weird and annoying but also shouting-at-the-sky territory so the Makefile is designed to hide the bother from you.

If you don't have `make` installed on your computer or just want to do things by hand then [you should spend some time reading the Makefile](Makefile) itself. The revelant "targets" (which are the equivalent of commands in Makefile-speak) that you will need are `deps` for fetching dependencies, `self` for cloning files and `bin` for building the command line tools.

_If you're a Go person and wondering why we don't just append the `vendor` directory to `GOPATH` and can explain to us [how to make Git and Go and submodules](https://github.com/facebookgo/grace/issues/27) and the presence (or absence...) of `.git` directories in the vendor-ed packages all play nicely together please please please [drop us a line](https://github.com/whosonfirst/go-whosonfirst-pip/issues). It the meantime this is the devil we know..._

## Usage

### The basics

```
package main

import (
	"github.com/whosonfirst/go-whosonfirst-pip"
)

source := "/usr/local/mapzen/whosonfirst-data"
p := pip.NewPointInPolygonSimple(source)

geojson_file := "/usr/local/mapzen/whosonfirst-data/data/101/736/545/101736545.geojson"
p.IndexGeoJSONFile(geojson_file)

# Or this:

meta_file := "/usr/local/mapzen/whosonfirst-data/meta/wof-locality-latest.csv"
p.IndexMetaFile(meta_file)
```

You can index individual GeoJSON files or [Who's On First "meta" files](https://github.com/whosonfirst/whosonfirst-data/tree/master/meta) which are just CSV files with pointers to individual Who's On First records.

The `PointInPolygon` function takes as its sole argument the root path where your Who's On First documents are stored. This is because those files are used to perform a final "containment" check. The details of this are discussed further below.

### Simple

```

lat := 40.677524
lon := -73.987343

results, timings := p.GetByLatLon(lat, lon)

for i, f := range results {
	fmt.Printf("simple result #%d is %s\n", i, f.Name)
}

for _, t := range timings {
        fmt.Printf("[timing] %s: %f\n", t.Event, t.Duration)
}
```

`results` contains a list of `geojson.WOFSpatial` object-interface-struct-things and `timings` contains a list of `pip.WOFPointInPolygonTiming` object-interface-struct-things. 

### What's going on under the hood

```
results, _ := p.GetIntersectsByLatLon(lat, lon)

for i, r := range results {
	fmt.Printf("spatial result #%d is %v\n", i, r)
}

inflated, _ := p.InflateSpatialResults(results)

for i, wof := range inflated {
	fmt.Printf("wof result #%d is %s\n", i, wof.Name)
}

# Assuming you're filtering on placetype

filtered, _ := p.FilterByPlacetype(inflated, "locality")

for i, f := range filtered {
	fmt.Printf("filtered result #%d is %s\n", i, f.Name)
}

contained, _ := p.EnsureContained(lat, lon, inflated)

for i, f := range contained {
	fmt.Printf("contained result #%d is %s\n", i, f.Name)
}

```

If you're curious how the sausage is made.

### HTTP Ponies

#### wof-pip-server

There is also a standalone HTTP server for performing point-in-polygon lookups. It is instantiated with a `data` parameter and one or more "meta" CSV files, like this:

```
./bin/wof-pip-server -data /usr/local/mapzen/whosonfirst-data/data/ -strict /usr/local/mapzen/whosonfirst-data/meta/wof-country-latest.csv /usr/local/mapzen/whosonfirst-data/meta/wof-neighbourhood-latest.csv 
indexed 50125 records in 64.023 seconds 
[placetype] country 219
[placetype] neighbourhood 49906
```

This is how you'd use it:

```
$> curl 'http://localhost:8080?latitude=40.677524&longitude=-73.987343' | python -mjson.tool
[
    {
        "Id": 102061079,
        "Name": "Gowanus Heights",
        "Placetype": "neighbourhood"
    },
    {
        "Id": 85633793,
        "Name": "United States",
        "Placetype": "country"
    },
    {
        "Id": 85865587,
        "Name": "Gowanus",
        "Placetype": "neighbourhood"
    }
]
```

There is an optional third `placetype` parameter which is a string (see also: [the list of valid Who's On First placetypes](https://github.com/whosonfirst/whosonfirst-placetypes)) that will limit the results to only records of a given placetype. Like this:

```
$> curl 'http://localhost:8080?latitude=40.677524&longitude=-73.987343&placetype=neighbourhood' | python -mjson.tool
[
    {
        "Id": 102061079,
        "Name": "Gowanus Heights",
        "Placetype": "neighbourhood"
    },
    {
        "Id": 85865587,
        "Name": "Gowanus",
        "Placetype": "neighbourhood"
    }
]
```

You can enable strict placetype checking on the server-side by specifying the `-strict` flag. This will ensure that the placetype being specificed has actually been indexed, returning an error if not. `pip-server` has many other option-knobs and they are:

```
$> ./bin/wof-pip-server -help
Usage of ./bin/wof-pip-server:
  -cache_all
	Just cache everything, regardless of size
  -cache_size int
    	      The number of WOF records with large geometries to cache (default 1024)
  -cache_trigger int
    		 The minimum number of coordinates in a WOF record that will trigger caching (default 2000)
  -cors
	Enable CORS headers
  -data string
    	The data directory where WOF data lives, required
  -gracehttp.log
	Enable logging. (default true)
  -host string
    	The hostname to listen for requests on (default "localhost")
  -loglevel string
    	    Log level for reporting (default "info")
  -logs string
    	Where to write logs to disk
  -metrics string
    	   Where to write (@rcrowley go-metrics style) metrics to disk
  -metrics-as string
    	      Format metrics as... ? Valid options are "json" and "plain" (default "plain")
  -pidfile string
    	   Where to write a PID file for wof-pip-server. If empty the PID file will be written to wof-pip-server.pid in the current directory
  -port int
    	The port number to listen for requests on (default 8080)
  -procs int
    	 The number of concurrent processes to clone data with (default 16)
  -strict
	Enable strict placetype checking
```

You can force `wof-pip-server` to reindex itself by sending a `USR2` signal to the server's process ID (which is recorded in the file specfied by the `pidfile` argument). For example:

```
kill -USR2 `cat /var/run/wof-pip-server.pid`
```

The server will return `502 Service Unavailable` errors to all requests made during the indexing process.

#### wof-pip-proxy

_Before you get started: You will need to install [py-mapzen-whosonfirst-pip-server](https://github.com/whosonfirst/py-mapzen-whosonfirst-pip-server) before any of this will work. It is likely that the tools described below will eventually be bundled with that package but this has not happened yet._

This is another HTTP pony that proxies requests to multiple instances of `wof-pip-server` routing the requests to multiple, separate URL paths on a single host. This is largely a convenience so that other parts of your code don't need to remember (or even think about) what port a given PIP server is running on. You would run it like this:

```
$> ./bin/wof-pip-proxy -config config.json 
proxying requests at localhost:1111
```

Here's what an example config file looks like:

```
[
    {"Target": "test", "Host": "localhost", "Port": 1212, "Meta": "/usr/local/mapzen/whosonfirst-data/meta/wof-continent-latest.csv" },
    {"Target": "locality", "Host": "localhost", "Port": 1213, "Meta": "/usr/local/mapzen/whosonfirst-data/meta/wof-locality-latest.csv" }
]
```

You can add as many targets are you want to your config file and the value of the `Target` property can be what ever you want (assuming it is URI safe).

There is also an handy tool in the `utils` directory called [mk-wof-config.py](https://github.com/whosonfirst/go-whosonfirst-pip/blob/master/utils/mk-wof-config.py) that will auto-generate a config file for one or more [placetypes](https://github.com/whosonfirst/whosonfirst-placetypes#roles) assigning each one a random port number and referencing their `meta` file in the [whosonfirst-data](https://github.com/whosonfirst/whosonfirst-data) repository. For example, to generate a config file for just the "common" placetypes you would do:

```
$> ./utils/mk-wof-config.py -d /usr/local/mapzen/whosonfirst-data/data -r common -o config.json
```

_Note: You will need to install the [py-mapzen-whosonfirst-placetypes](https://github.com/whosonfirst/py-mapzen-whosonfirst-placetypes) Python library for the `mk-wof-config.py` script to work. Eventually this functionality might be rewritten in Go but not today._

Finally, this is how you might look something up using the `wof-pip-proxy` server:

```
$> curl -s 'http://localhost:1111/locality?latitude=40.677524&longitude=-73.987343' | python -mjson.tool
[
    {
        "Id": 85977539,
        "Name": "New York",
        "Offset": -1,
        "Placetype": "locality"
    }
]

$> curl -s 'http://localhost:1111/test?latitude=40.677524&longitude=-73.987343' | python -mjson.tool
[
    {
        "Id": 102191575,
        "Name": "North America",
        "Offset": -1,
        "Placetype": "continent"
    }
]
```

The `wof-pip-proxy` server only proxies _already running instances_ of `wof-pip-server`. There are boring computer reasons for this and they are boring and computer-y. Instead there is also a _separate_ Python utility included with this repository for starting up (n) number of instances of `wof-pip-server` as defined in your config file and then finally starting a copy of `wof-pip-proxy`. For example:

```
$> ./utils/wof-pip-proxy-start.py -d /usr/local/mapzen/whosonfirst-data/data/ --proxy-config config.json 

# depending on your proxy config a lot of stuff like this...

INFO:root:ping for http://localhost:1213 failed, waiting
INFO:root:pause...
INFO:root:ping for http://localhost:1213 failed, waiting
INFO:root:pause...
[wof-pip-server] 03:24:15.671671 [warning] scheduling /usr/local/mapzen/whosonfirst-data/data/102/023/977/102023977.geojson for pre-caching because its time to load exceeds 0.01 se\
conds: 0.012060
[wof-pip-server] 03:24:15.982738 [status] indexed 160682 records in 92.611 seconds
[wof-pip-server] 03:24:15.982768 [status] indexed locality: 160682

# followed eventually by this...

proxying requests at localhost:1111
```

And then, just like the example above:

```
$> curl -s 'http://localhost:1111/locality?latitude=40.677524&longitude=-73.987343' | python -mjson.tool
[
    {
        "Id": 85977539,
        "Name": "New York",
        "Offset": -1,
        "Placetype": "locality"
    }
]

$> curl -s 'http://localhost:1111/test?latitude=40.677524&longitude=-73.987343' | python -mjson.tool
[
    {
        "Id": 102191575,
        "Name": "North America",
        "Offset": -1,
        "Placetype": "continent"
    }
]
```

## Metrics

This package uses Richard Crowley's [go-metrics](https://github.com/rcrowley/go-metrics) package to record general [memory statistics](https://golang.org/pkg/runtime/#MemStats) and a handful of [custom metrics](https://github.com/whosonfirst/go-whosonfirst-pip/blob/master/pip.go#L20-L32).

### Custom metrics

#### pip.reversegeo.lookups

The total number of reverse geocoding lookups. This is a `metrics.Counter`.

#### pip.geojson.unmarshaled

The total number of time any GeoJSON file has been unmarshaled. This is a `metrics.Counter` thingy.

#### pip.cache.hit

The number of times a record has been found in the LRU cache. This is a `metrics.Counter` thingy.

#### pip.cache.miss

The number of times a record has _not_ been found in the LRU cache. This is a `metrics.Counter` thingy.

#### pip.cache.set

The number of times a record has been added to the LRU cache. This is a `metrics.Counter` thingy.

#### pip.timer.reversegeo

The total amount of time to complete a reverse geocoding lookup. This is a `metrics.Timer` thingy.

#### pip.timer.unmarshal

The total amount of time to read and unmarshal a GeoJSON file from disk. This is a `metrics.Timer` thingy.

#### pip.timer.containment

The total amount of time to perform final raycasting intersection tests. This is a `metrics.Timer` thingy.

### Configuring metrics

If you are using the `pip` package in your own program you will need to tell the package where to send the metrics. You can do this by passing the following to the `SendMetricsTo` method:

* Anything that implements an `io.Writer` interface
* The frequency that metrics should be reported as represented by something that implements the `time.Duration` interface
* Either `plain` or `json` which map to the [metrics.Log](https://github.com/rcrowley/go-metrics/blob/master/log.go) and [metrics.JSON](https://github.com/rcrowley/go-metrics/blob/master/json.go) packages respectively

#### Example

```
m_file, m_err := os.OpenFile("metrics.log", os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0660)

if m_err != nil {
	panic(m_err)
}

m_writer = io.MultiWriter(m_file)
_ = p.SendMetricsTo(m_writer, 60e9, "plain")
```

## Assumptions, caveats and known-knowns

### When we say `geojson` in the context of Go-typing

We are talking about the [go-whosonfirst-geojson](https://www.github.com/whosonfirst/go-whosonfirst-geojson) library.

### Speed and performance

This is how it works now:

1. We are using the [rtreego](https://www.github.com/dhconnelly/rtreego) library to do most of the heavy lifting and filtering.
2. Results from the rtreego `SearchIntersect` method are "inflated" and recast as geojson `WOFSpatial` object-interface-struct-things.
3. We are performing a final containment check on the results by reading each corresponding GeoJSON file using [go-whosonfirst-geojson](https://github.com/whosonfirst/go-whosonfirst-geojson) and calling the `Contains` method on each of the items returned by the `GeomToPolygon` method. What's _actually_ happening is that the GeoJSON geometry is being converted in to one or more [golang-geo](https://www.github.com/kellydunn/golang-geo) `Polygon` object-interface-struct-things. Each of these object-interface-struct-things calls its `Contains` method on an input coordinate.
4. If any given set of `Polygon` object-interface-struct-things contains more than `n` points (where `n` is defined by the `CacheTrigger` constructor thingy or the `cache_trigger` command line argument) it is cached using the [golang-lru](https://github.com/hashicorp/golang-lru) package.

### Caching

We are aggressively pre-caching large (or slow) GeoJSON files or GeoJSON files with large geometries in the LRU cache. As of this writing during the start-up process when we are building the Rtree any GeoJSON file that takes > 0.01 seconds to load is tested to see whether it has >= 2000 vertices. If it does then it is added to the LRU cache.

Both the size of the cache and the trigger (number of vertices) are required parameters when instatiating a `WOFPointInPolygon` object-interface-struct thing. Like this:

```
func NewPointInPolygon(source string, cache_size int, cache_trigger int, logger *log.WOFLogger) (*WOFPointInPolygon, error) {
     // ...
}
```

You should adjust these values to taste. If you are adding more records to the cache than you've allocated space for the package will emit warnings telling you that, during the start-up phase.

This is all to account for the fact that some countries, like [New Zealand](https://whosonfirst.mapzen.com/spelunker/id/85633345/) are known to be problematic because they have an insanely large "ground truth" polygon, but the caching definitely helps. For example, reverse-geocoding `-40.357418,175.611481` looks like this:

```
[debug] time to marshal /usr/local/mapzen/whosonfirst-data/data/856/333/45/85633345.geojson is 5.419391
[debug] time to convert geom to polygons (3022193 points) is 0.326103
[cache] 85633345 because so many points (3022193)
[debug] time to load polygons is 5.745573
[debug] time to check containment (true) after 1524/5825 possible iterations is 0.020504
[debug] contained: 1/1
[timings] -40.357418, 175.611481 (1 result)
[timing] intersects: 0.000081
[timing] inflate: 0.000004
[timing] placetype: 0.000001
[timing] contained: 5.766121
```

This is what things look like loading the same data from cache:

```
[debug] time to load polygons is 0.000003
[debug] time to check containment (true) after 1524/5825 possible iterations is 0.020891
[debug] contained: 1/1
[timings] -40.357418, 175.611481 (1 result)
[timing] intersects: 0.000082
[timing] inflate: 0.000001
[timing] placetype: 0.000001
[timing] contained: 0.020952
```

So the amount of time it takes to perform the final point-in-polygon test is relatively constant but the difference between fetching the cached and uncached polygons to test is `0.000003` seconds versus `5.419391` so that's a thing.

There is a separate on-going process for [sorting out geometries in Who's On First](https://github.com/whosonfirst/whosonfirst-geometries) but on-going work is on-going. Whatever the case there is room for making this "Moar Faster".

### Load testing

Individual reverse geocoding lookups are almost always sub-second responses. After unmarshaling GeoJSON files (which are cached) the bottleneck appears to be in the final raycasting intersection tests for anything that is a match in the Rtree and warnings are emitted for anything that takes longer than 0.5 seconds. Although there is room for improvement here (a more efficient raycasting, etc. ) this is mostly only a problem for countries and very large and fiddly cities as evidenced by our load-testing benchmarks.

```
$> siege -c 100 -i -f urls.txt
** SIEGE 3.0.5
** Preparing 100 concurrent users for battle.
The server is now under siege...^C
Lifting the server siege...      done.

Transactions:				57270 hits
Availability:				100.00 %
Elapsed time:				314.56 secs
Data transferred:			3.18 MB
Response time:				0.05 secs
Transaction rate:			182.06 trans/sec
Throughput:				0.01 MB/sec
Concurrency:				8.68
Successful transactions:		57270
Failed transactions:			0
Longest transaction:			1.70
Shortest transaction:			0.00

$> siege -c 500 -i -f urls.txt
** SIEGE 3.0.5
** Preparing 500 concurrent users for battle.
The server is now under siege...^C
Lifting the server siege...      done.

Transactions:				118034 hits
Availability:				99.98 %
Elapsed time:				475.11 secs
Data transferred:			6.56 MB
Response time:				1.47 secs
Transaction rate:			248.44 trans/sec
Throughput:				0.01 MB/sec
Concurrency:				365.65
Successful transactions:		118034
Failed transactions:			20
Longest transaction:			65.09
Shortest transaction:			0.03

$> siege -c 250 -i -f urls.txt
** SIEGE 3.0.5
** Preparing 250 concurrent users for battle.
The server is now under siege...^C
Lifting the server siege...      done.

Transactions:				96861 hits
Availability:				100.00 %
Elapsed time:				390.72 secs
Data transferred:			5.38 MB
Response time:				0.51 secs
Transaction rate:			247.90 trans/sec
Throughput:				0.01 MB/sec
Concurrency:				125.76
Successful transactions:		96861
Failed transactions:			0
Longest transaction:			4.07
Shortest transaction:			0.01

$> siege -c 300 -i -f urls-wk.txt 
siege aborted due to excessive socket failure; you
can change the failure threshold in $HOME/.siegerc

Transactions:				897266 hits
Availability:				99.85 %
Elapsed time:				3760.40 secs
Data transferred:			43.62 MB
Response time:				0.67 secs
Transaction rate:			238.61 trans/sec
Throughput:				0.01 MB/sec
Concurrency:				160.68
Successful transactions:		896961
Failed transactions:			1323
Longest transaction:			31.51
Shortest transaction:			0.01
```

### Memory usage

Memory usage will depend on the data that you've imported, obviously. In the past (before we cached things so aggressively) it was possible to send the `pip-server` in to an ungracious death spiral by hitting the server with too many concurrent requests that required it to load large country GeoJSON files.

Pre-caching files seems to account for this problem (see load testing stats above) but as with any service I'm sure there is still a way to overwhelm it. The good news is that in the testing we've done so far memory usage for the `pip-server` remains pretty constant regardless of the number of connections attempting to talk to it.

For a server loading all of the [countries](https://github.com/whosonfirst/whosonfirst-data/blob/master/meta/wof-country-latest.csv), [localities](https://github.com/whosonfirst/whosonfirst-data/blob/master/meta/wof-locality-latest.csv) and [neightbourhoods](https://github.com/whosonfirst/whosonfirst-data/blob/master/meta/wof-neighbourhood-latest.csv) in Who's On First these are the sort of numbers (measured in bytes) we're seeing as reported by the metrics package:

```
$> /bin/grep -A 1 runtime.MemStats.Alloc metrics.log
[pip-metrics] 23:39:13.978103 gauge runtime.MemStats.Alloc
[pip-metrics] 23:39:13.978107   value:       876122856

$> /bin/grep -A 1 runtime.MemStats.HeapInuse metrics.log
[pip-metrics] 23:39:13.977245 gauge runtime.MemStats.HeapInuse
[pip-metrics] 23:39:13.977249   value:       1273307136
```

### Using this with other data sources

Yes! With the following provisos:

1. Currently only GeoJSON `Feature` records are supported. You can not index `FeatureCollections` yet. I mean you could write the code to index them but the code doesn't do it for you yet.
2. Your GeoJSON `properties` dictionary has the following keys: `id`, `name` and `placetype`. The values can be anything (where "anything" means something that can be converted to an integer in the case of the `id` key).
3. Your GeoJSON `feature` dictionary has a `bbox` key that is an array of coordinates, [per the GeoJSON spec](http://geojson.org/geojson-spec.html#bounding-boxes).
4. Your GeoJSON file ends with `.geojson` (and not say `.json` or something else)

### Less-than-perfect GeoJSON files

First, these should not be confused with malformed GeoJSON files. Some records in Who's On First are missing geometries or maybe the geometries are... well, less than perfect. The `rtreego` package is very strict about what it can handle and freaks out and dies rather than returning errors. So that's still a thing. Personally I like the idea of using `pip-server` as a kind of unfriendly validation tool for Who's On First data but it also means that, for the time being, it is understood that some records may break everything.

## See also

* https://github.com/whosonfirst/chef-wof_pip
* https://www.github.com/dhconnelly/rtreego
* https://github.com/hashicorp/golang-lru
* https://github.com/rcrowley/go-metrics
* https://www.github.com/whosonfirst/go-whosonfirst-geojson
* https://whosonfirst.mapzen.com/data/

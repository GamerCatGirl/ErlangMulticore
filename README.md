# Microblogging service

*Multicore Programming 2024 - Erlang Project*

This directory contains an implementation of the microblogging service with one server process.

It contains the following files:
* server.erl: the protocol that is used to interact with an implementation of the service.
* server_centralized.erl: an implementation of the service that only uses one Erlang process.
* benchmark.erl: a starting point for benchmarks of your project.
* run_benchmarks.sh: a script that runs the benchmarks and stores the results to files.
* run.sh and run.bat: helper scripts run your files, like seen in class.
* Makefile: a Makefile that compiles the project:
    - make all: compile the project.
    - make test: run the accompanying tests.
    - make benchmark: compile the project and run the benchmarks.
    - make clean: remove all compiled files.

To visualize benchmark results, we also provide a Python script that uses [matplotlib](https://matplotlib.org/):
* benchmarks/process_results.py: a Python script that parses benchmark results, calculates
  statistics, and generates plots.
* benchmarks/requirements.txt: a file listing the dependencies of the Python script, for use with pip.

To run the Python script, you first need to install the dependencies, preferably in a virtual environment:

```sh
$ cd benchmarks
# Create a new virtual environment in the folder venv:
$ python3 -m venv venv
# Activate the virtual environment in the current shell session:
$ source venv/bin/activate
# Install the dependencies:
$ pip install -r requirements.txt
```

Every time you create a new terminal session, you'll need to activate the virtual environment first:

```sh
$ source venv/bin/activate
# You can now run:
$ python process_results.py
```

The script expects the benchmark results to be in files with names like `result-fib-1.txt`, in the benchmarks folder. The `run_benchmarks.sh` script puts them there.

## Task 
In the given example implementation, in server_centralized.erl, the server is a single process that contains all data discussed in the previous section. You will need to change this to increase scalability.

A server should support the operations listed in the API definition, in server.erl. Their semantics are supposed to remain unchanged:

• register_user: Register a new user, with an empty timeline.

• log_in: Log in as a certain user.

• follow:Follow another user.After this request,the timeline of the current user should contain the messages from the followed user.

• send_message: Send a message. The message is saved on the server. The timestamp of the message should represent the wall clock time when the message was received.

• get_timeline: Get the user’s timeline. The result includes a (perhaps partially stale) view of all messages of the users that this user is following.

• get_profile: Get all messages of a user.


**Notes**

• This assignment is about modeling a scalable system using Erlang processes and message passing. Hence, do not use Erlang databases like Mnesia or Riak, or frameworks like Erlang’s OTP or Rab- bitMQ. They will obscure your results and make it harder to compare approaches.

• The aim of this project is to focus on parallelism, not distribution. You should therefore not ex- periment with distributing server processes over multiple machines, instead, run everything in one Erlang VM and use regular message passing to communicate between processes.

• Furthermore,your application only needs to support the minimal set of operations described above, and should not support any of the advanced features that real applications offer. Focus on the parallel and concurrency aspects.

• Finally, you do not need to take into account authentication or privacy. Our system for instance does not have passwords and allows users to log in and send messages in the name of other users. For the purposes of this project, you should not take these concerns into account.

**Pitfalls**

• Garbage collection issues:spawn new processes foreach benchmark run,and make sure that they terminate after the benchmark. I.e. each of the 30 repetitions should spawn new, freshly initialized, server processes.

• Does your CPU support Intel’s Hyper-Threading: on processors with Hyper-Threading, sev- eral (usually two) hardware threads run on each core. E.g. your machine might contain two cores, which each run two hardware threads, hence your operating system will report four
“virtual” (or “logical”) cores. However, you might not get a 4× speed-up even in the ideal case.

• Does your CPU support Turbo Boost? This allows your processor to run at a higher clock rate than normal. It will be enabled in certain situations, when the workload is high, but it is restricted by power, current, and temperature limits. For example, on a laptop it might only be enabled when the AC power is connected. So, make sure to keep the power connected.

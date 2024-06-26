ERL_SRC = $(wildcard *.erl)
BEAM	= $(ERL_SRC:.erl=.beam)

all: $(BEAM)

test: $(BEAM)
	./run.sh server_centralized test
	./run.sh server_parallelized test
	./run.sh server_parallelized_new test

benchmark: $(BEAM)
	./run_benchmarks.sh

clean:
	rm -f *.beam erl_crash.dump

%.beam: %.erl
	erlc +debug_info $*.erl

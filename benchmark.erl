-module(benchmark).

-export([test_fib/0, test_timeline/0, test_send_message/0]).

%% Fibonacci
fib(0) -> 1;
fib(1) -> 1;
fib(N) -> fib(N - 1) + fib(N - 2).

%% Benchmark helpers

% Recommendation: run each test at least 30 times to get statistically relevant
% results.
%

run_benchmark(Name, Fun, Times) ->
    ThisPid = self(),
    lists:foreach(fun (N) ->
        % Recommendation: to make the test fair, each run executes in its own,
        % newly created Erlang process. Otherwise, if all tests run in the same
        % process, the later tests start out with larger heap sizes and
        % therefore probably do fewer garbage collections. Also consider
        % restarting the Erlang emulator between each test.
        % Source: http://erlang.org/doc/efficiency_guide/profiling.html
        spawn_link(fun () ->
            run_benchmark_once(Name, Fun, N),
            ThisPid ! done
        end),
        receive done ->
            ok
        end
    end, lists:seq(1, Times)).

run_benchmark_once(Name, Fun, N) ->
    io:format("Starting benchmark ~s: ~p~n", [Name, N]),

    % Start timers
    % Tips:
    % * Wall clock time measures the actual time spent on the benchmark.
    %   I/O, swapping, and other activities in the operating system kernel are
    %   included in the measurements. This can lead to larger variations.
    %   os:timestamp() is more precise (microseconds) than
    %   statistics(wall_clock) (milliseconds)
    % * CPU time measures the actual time spent on this program, summed for all
    %   threads. Time spent in the operating system kernel (such as swapping and
    %   I/O) is not included. This leads to smaller variations but is
    %   misleading.
    StartTime = os:timestamp(), % Wall clock time
    %statistics(runtime),       % CPU time, summed for all threads

    % Run
    Fun(),

    % Get and print statistics
    % Recommendation [1]:
    % The granularity of both measurement types can be high. Therefore, ensure
    % that each individual measurement lasts for at least several seconds.
    % [1] http://erlang.org/doc/efficiency_guide/profiling.html
    WallClockTime = timer:now_diff(os:timestamp(), StartTime),
    %{_, CpuTime} = statistics(runtime),
    io:format("Wall clock time = ~p ms~n", [WallClockTime / 1000.0]),
    %io:format("CPU time = ~p ms~n", [CpuTime]),
    io:format("~s done~n", [Name]).

%% Benchmarks
% Below are some example benchmarks. Extend these to test the best and worst
% case of your implementation, some typical scenarios you imagine, or some
% extreme scenarios.

test_fib() ->
    io:format("Parameters:~n"),
    io:format("~n"),
    run_benchmark("fib", fun test_fib_benchmark/0, 30).

test_fib_benchmark() ->
    % Spawn 64 processes that each compute the 30th Fibonacci number.
    BenchmarkPid = self(),
    Pids = [spawn(fun () ->
        fib(30),
        BenchmarkPid ! done
    end) || _ <- lists:seq(1, 64)],
    lists:foreach(fun (_) ->
        receive done ->
            ok
        end
    end, Pids).

% Creates a server with 5000 users following 25 others and sending 10 messages.
%
% Note that this code depends on the implementation of the server. You will need to
% change it if you change the representation of the data in the server.
initialize_server(Treshold, NumberOfUsers, NumberOfSubscriptions, NumberOfMessages) ->
    % Seed random number generator to get reproducible results.
    rand:seed_s(exsplus, {0, 0, 0}),
   

	
    %In een normale omstandigheden heb je normaal meer messages and followers than users, dus om dit te representeren wil ik 
   
    ServerPid = server_parallelized_new:initialize_new(Treshold),
   
    %ServerPid = server_parallelized:initialize(),
    % Generate user names: just the numbers from 1 to NumberOfUsers, as strings.
    % Note: integer_to_list convert an integer to a string, e.g. 123 to "123".
    % Note: the syntax [F(X) || X <- L] is a list comprehension. It generates a list
    % by applying F to each element of L. It is equivalent to
    % lists:map(fun (X) -> F(X) end, L).
    UserNames = [integer_to_list(I) || I <- lists:seq(1, NumberOfUsers)],

    RegisteredUsersPred = fun (Name) -> 
			   %1. Register the user
			   {PiD, _} = server:register_user(ServerPid, Name),

			   {PiD, Name}
	   end,

   
    RegisteredUsers = lists:map(RegisteredUsersPred, UserNames),


   FollowAndSendMessage = fun(Elm) ->
				{PiD, Name} = Elm,
				loop_follow(PiD, Name, RegisteredUsers, NumberOfSubscriptions),
				loop_sendmessage(PiD, Name, NumberOfMessages),
				{PiD, Name}
		end,

   {lists:map(FollowAndSendMessage, RegisteredUsers), ServerPid}.


loop_follow(_, _, _, 0) ->  ok;
loop_follow(PiD, Name, Users, Count) ->
	UserNameToFollow = pick_random_user(Users),
	NewUsers = lists:delete(UserNameToFollow, Users),
        %io:format("User ~p followed ~p~n", [Name, UserNameToFollow]),
	server:follow(PiD, Name, UserNameToFollow),
	loop_follow(PiD, Name, NewUsers, Count - 1).


loop_sendmessage(_, _, 0) -> ok;
loop_sendmessage(Pid, Name, Count) ->
	Message = generate_string(Name, Count),
        %io:format("User ~p send message ~p~n", [Name, Message]),
	server:send_message(Pid, Name, Message),
	loop_sendmessage(Pid, Name, Count - 1).
	

pick_random_user(List) ->
	{_, Name} = pick_random(List),
	Name.


% Pick a random element from a list.
pick_random(List) ->
    lists:nth(rand:uniform(length(List)), List).


% Generate a random subscription for 'UserName'
generate_subscription(UserNames) ->
	Key = pick_random(UserNames),
	Value = {unknown, []}, %server of Username and messages 
	{Key, Value}.


% Generate random string 
generate_string(UserName, I) -> "Message " ++ integer_to_list(I) ++ " from " ++ UserName.

 


% Generate a random message `I` for `UserName`.
generate_message(UserName, I) ->
    Text = "Message " ++ integer_to_list(I) ++ " from " ++ UserName,
    {message, UserName, Text, os:system_time()}.


cleanup(InitServer, _) ->
      InitServer ! {stop}.


% Get timeline of 10000 users (repeated 30 times).
test_timeline() ->
    %InitializedServers = initializeServers(),
    NumberOfUsers = 5000,
    NumberOfSubscriptions = 25,
    NumberOfMessages = 10,
    Thresholds = [6000, 3000, 1500, 500, 100, 10, 5, 1],
    io:format("Parameters:~n"),
    io:format("Number of users: ~p~n", [NumberOfUsers]),
    io:format("Number of subscriptions: ~p~n", [NumberOfSubscriptions]),
    io:format("Number of messages: ~p~n", [NumberOfMessages]),
    io:format("~n"),

    Func = fun(Threshold) ->
	io:format("------------ Threshold: ~p ------------ ~n", [Threshold]),
	{ListsUserPids, InitServer} = initialize_server(Threshold, NumberOfUsers, NumberOfSubscriptions, NumberOfMessages),
    
    	Done = run_benchmark("timeline",
        	fun () ->
           		 lists:foreach(fun (_) ->
			{PiD, User} = pick_random(ListsUserPids),
               		 server:get_timeline(PiD, User)
            	end,
           	 lists:seq(1, 10000))
        	end,
        	30),
	   cleanup(InitServer, Done)

	   end, 

	lists:map(Func, Thresholds).

% Send message for 10000 users.
test_send_message() ->
    NumberOfUsers = 5000,
    NumberOfSubscriptions = 25,
    NumberOfMessages = 10,
    Thresholds = [6000, 3000, 1500, 1000, 500, 100, 10, 5, 1],

    io:format("Parameters:~n"),
    io:format("Number of users: ~p~n", [NumberOfUsers]),
    io:format("Number of subscriptions: ~p~n", [NumberOfSubscriptions]),
    io:format("Number of messages: ~p~n", [NumberOfMessages]),
    io:format("~n"),

    Func = fun(Threshold) ->
	io:format("------------ Threshold: ~p ------------ ~n", [Threshold]),
	{ListsUserPids, InitServer} = initialize_server(Threshold, NumberOfUsers, NumberOfSubscriptions, NumberOfMessages),
    


    Done = run_benchmark("send_message",
        fun () ->
            lists:foreach(fun (_) ->	
                {PiD, User} = pick_random(ListsUserPids),
                server:send_message(PiD, User, "Test")
            end,
            lists:seq(1, 10000))
        end,
        30),
    cleanup(InitServer, Done)
	
	   end,

    lists:map(Func, Thresholds).

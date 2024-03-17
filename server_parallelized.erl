%% This is a simple implementation of the project, using one server process.
%%
%% It will create one "server" actor that contains all internal state (users,
%% their subscriptions, and their messages).
%%
%% This implementation is provided with unit tests, however, these tests are
%% neither complete nor implementation independent, so be careful when reusing
%% them.
-module(server_parallelized).

-include_lib("eunit/include/eunit.hrl").

-export([initialize/0, initialize_with/3, server_actor/3, typical_session_1/1,
    typical_session_2/1]).

%%
%% Additional API Functions
%%

% Start server.
initialize() ->
    initialize_with(orddict:new(), 32, 126). %username without extended ascii 

% Start server with an initial state.
% Useful for benchmarking.
initialize_with(Users, CharBegin, CharEnd) ->
    ServerPid = spawn_link(?MODULE, server_actor, [Users, CharBegin, CharEnd]),
   
    catch unregister(server_actor),
    register(server_actor, ServerPid),
    ServerPid.

% The server actor works like a small database and encapsulates all state of
% this simple implementation.
%
% Users is a dictionary of user names to tuples of the form:
%     {user, Name, Subscriptions, Messages}
% where Subscriptions is a set of usernames that the user follows, and
% Messages is a list of messages, of the form:
%     {message, UserName, MessageText, SendTime}
%
%
%
%
%Client to server 
server_actor(Users, CharBegin, CharEnd) ->
    TreshHoldUsers = 5, %differ this to test the parallel process 
    receive
% When message received, spawn new 
        {Sender, register_user, UserName} ->
	    erlang:display(UserName),
	    %dict is stoted from A, B, C, ... a, b, c 
            NewUsers = orddict:store(UserName, create_user(UserName), Users),
            Sender ! {self(), user_registered},
            
             %When too much registered_users -> make a parallel server that handles half of the users ?
	    AmountOfUsers = orddict:size(NewUsers),
	    %Filter = fun((Key, Value) -> boolean())
	    %erlang:display(Users),
            
            
	    if AmountOfUsers > TreshHoldUsers ->
		       erlang:display("Splitting Users over different servers..."),
		       Range = CharEnd - CharBegin,
		       NewRange = Range div 2,
		       Split = CharBegin + NewRange,
		       erlang:display(Split),
		       Filter = fun (K, V) -> 
						FirstChar = lists:nth(1, K), 
						FirstChar > Split 
				end,
		       ReversedFilter = fun(K, V) -> not Filter(K, V) end,
			%TODO: make sure that if you have multiple with same starting letter that it somtimes also looks further than the first charachter 
		       
		       % Filter: get all where Filter is True 
	               Users2 = orddict:filter(Filter, NewUsers),

                       % Remove: all where Filter is True
                       Users1 = orddict:filter(ReversedFilter, NewUsers),

		       NewPid = initialize_with(Users2, Split, CharEnd),

		       OldPid = server_actor(Users1, CharBegin, Split),

	       	       FirstChar = lists:nth(1, UserName), 
		     	if 
			       FirstChar > Split ->
				       erlang:display(NewPid),
				       NewPid;
		       true -> 
				       erlang:display(OldPid),
				       OldPid 
		       end;
		       %TODO: make a link between the servers to communicate with each other
		       %TODO: split the Users such that each server has a range of alfabetic letters, easier to send to other servers, to get a message
		true -> 
		       server_actor(NewUsers, CharBegin, CharEnd)
	   end;
		       
           % server_actor(NewUsers);

        {Sender, log_in, UserName} ->
	    erlang:display("Username logging in: "),
	    erlang:display(UserName),
	    erlang:display(CharBegin),
            % This doesn't do anything, but you could use this operation if needed.
            Sender ! {self(), logged_in},
            server_actor(Users, CharBegin, CharEnd);

        {Sender, follow, UserName, UserNameToFollow} ->
            NewUsers = follow(Users, UserName, UserNameToFollow),
            Sender ! {self(), followed},
            server_actor(NewUsers, CharBegin, CharEnd);

        {Sender, send_message, UserName, MessageText, Timestamp} ->
            NewUsers = store_message(Users, {message, UserName, MessageText, Timestamp}),
            Sender ! {self(), message_sent},
            server_actor(NewUsers, CharBegin, CharEnd);

        {Sender, get_timeline, UserName} ->
            Sender ! {self(), timeline, UserName, timeline(Users, UserName)},
            server_actor(Users, CharBegin, CharEnd);


        {Sender, get_profile, UserName} ->
            Sender ! {self(), profile, UserName, sort_messages(get_messages(Users, UserName))},
            server_actor(Users, CharBegin, CharEnd)
    end.

%%
%% Internal Functions
%%

% Create a new user with `UserName`.
create_user(UserName) ->
    {user, UserName, sets:new(), []}.

% Get user with `UserName` in `Users`.
% Throws an exception if user does not exist (to help in debugging).
% In your project, you do not need specific error handling for users that do not exist;
% you can assume that all users that use the system exist.
get_user(UserName, Users) ->
    case dict:find(UserName, Users) of
        {ok, User} -> User;
        error -> throw({user_not_found, UserName})
    end.

% Update `Users` so `UserName` follows `UserNameToFollow`.
follow(Users, UserName, UserNameToFollow) ->
    {user, Name, Subscriptions, Messages} = get_user(UserName, Users),
    NewUser = {user, Name, sets:add_element(UserNameToFollow, Subscriptions), Messages},
    dict:store(UserName, NewUser, Users).

% Modify `Users` to store `Message`.
store_message(Users, Message) ->
    {message, UserName, _MessageText, _Timestamp} = Message,
    {user, Name, Subscriptions, Messages} = get_user(UserName, Users),
    NewUser = {user, Name, Subscriptions, Messages ++ [Message]},
    dict:store(UserName, NewUser, Users).

% Get all messages by `UserName`.
get_messages(Users, UserName) ->
    {user, _, _, Messages} = get_user(UserName, Users),
    Messages.

% Generate timeline for `UserName`.
timeline(Users, UserName) ->
    {user, _, Subscriptions, _} = get_user(UserName, Users),
    UnsortedMessagesForTimeLine =
        lists:foldl(fun(FollowedUserName, AllMessages) ->
                        AllMessages ++ get_messages(Users, FollowedUserName)
                    end,
                    [],
                    sets:to_list(Subscriptions)),
    sort_messages(UnsortedMessagesForTimeLine).

% Sort `Messages` from most recent to oldest.
sort_messages(Messages) ->
    % Sort on the 4th element of the message tuple (= timestamp, this uses 1-based
    % indexing), and then reverse to put most recent first.
    lists:reverse(lists:keysort(4, Messages)).

%%
%% Tests
%%
% These tests are for this specific implementation. They are a partial
% definition of the semantics of the provided interface but also make certain
% assumptions of the implementation. You can re-use them, but you might need to
% modify them.

% Test initialize function.
initialize_test() ->
    catch unregister(server_actor),
    initialize().

% Initialize server and test user registration of 4 users.
% Returns list of user names to be used in subsequent tests.
register_user_test() -> %register is sequential, but all the rest of the requests are in parallel
    io:write("Registering users..."),
    erlang:display("Registering users..."),
    initialize_test(),

    UserName1 = "A",
    UserName2 = "B", 
    UserName3 = "C", 
    UserName4 = "D",
    UserName5 = "W",
    UserName6 = "X",
    UserName7 = "Y",
    UserName8 = "Z",


    {Server1, Response1} = server:register_user(server_actor, UserName1),
    {Server2, Response2} = server:register_user(server_actor, UserName2),
    {Server3, Response3} = server:register_user(server_actor, UserName3),
    {Server4, Response4} = server:register_user(server_actor, UserName4),
    {Server5, Response5} = server:register_user(server_actor, UserName5),
    {Server6, Response6} = server:register_user(server_actor, UserName6),
    {Server7, Response7} = server:register_user(server_actor, UserName7),
    {Server8, Response8} = server:register_user(server_actor, UserName8),


    ?assertMatch(user_registered, Response1),
    ?assertMatch(user_registered, Response2),
    ?assertMatch(user_registered, Response3),
    ?assertMatch(user_registered, Response4),
    ?assertMatch(user_registered, Response5),
    ?assertMatch(user_registered, Response6),
    ?assertMatch(user_registered, Response7),
    ?assertMatch(user_registered, Response8),
     [UserName1, Server1, UserName2, Server2, UserName3, Server3, UserName4, Server4, UserName5, Server5, UserName6, Server6, UserName7, Server7, UserName8, Server8].
    % Test log in.
log_in_test() ->
    erlang:display("Logging in users..."),
    [UserName1, Server1, UserName2, Server2, UserName3, Server3, UserName4, Server4, UserName5, Server5, UserName6, Server6, UserName7, Server7, UserName8, Server8 | _] = register_user_test(),
    LoggedInUser1 = server:log_in(Server1, UserName1),
    erlang:display(LoggedInUser1),
    LoggedInUser6 = server:log_in(Server8, UserName8),
    erlang:display(LoggedInUser6),
    ?assertMatch({_Server1, logged_in}, LoggedInUser1),
    ?assertMatch({_Server2, logged_in}, LoggedInUser6).
  
    % Note: returned pids _Server1 and _Server2 do not necessarily need to be
    % the same.

% Test follow: user 1 will follow 2 and 3.
follow_test() ->
    erlang:display("Following users ..."),
    [UserName1, UserName2, UserName3 | _ ] = register_user_test(),
    {Server1, logged_in} = server:log_in(server_actor, UserName1),
    ?assertMatch(followed, server:follow(Server1, UserName1, UserName2)),
    ?assertMatch(followed, server:follow(Server1, UserName1, UserName3)),
    {UserName1, Server1, [UserName2, UserName3]}.

% Test sending a message.
send_message_test() ->
    {UserName1, Server1, Subscriptions} = follow_test(),
    ?assertMatch(message_sent,
        server:send_message(Server1, UserName1, "Hello!")),
    ?assertMatch(message_sent,
        server:send_message(Server1, UserName1, "How is everyone?")),
    {UserName1, Server1, Subscriptions}.

% Test getting a timeline.
get_timeline_test() ->
    {UserName1, Server1, [UserName2, UserName3]} = follow_test(),

    % When nothing has been sent, the timeline is empty.
    ?assertMatch([], server:get_timeline(Server1, UserName1)),

    ?assertMatch(message_sent,
        server:send_message(Server1, UserName2, "Hello I'm B!")),

    % One message in the timeline.
    ?assertMatch([
        {message, UserName2, "Hello I'm B!", _TimeB1}
    ], server:get_timeline(Server1, UserName1)),

    ?assertMatch(message_sent,
        server:send_message(Server1, UserName2, "How is everyone?")),
    ?assertMatch(message_sent,
        server:send_message(Server1, UserName3, "Hello I'm C!")),

    % All three messages in the timeline, newest first.
    ?assertMatch([
        {message, UserName3, "Hello I'm C!", _TimeC1},
        {message, UserName2, "How is everyone?", _TimeB2},
        {message, UserName2, "Hello I'm B!", _TimeB1}
    ], server:get_timeline(Server1, UserName1)),

    % User 2 does not follow any so gets an empty timeline.
    ?assertMatch([], server:get_timeline(Server1, UserName2)).

% Test getting the profile.
get_profile_test() ->
    {UserName1, Server1, [UserName2 | _]} = send_message_test(),
    % Most recent message is returned first.
    ?assertMatch([
        {message, UserName1, "How is everyone?", _TimeA2},
        {message, UserName1, "Hello!", _TimeA1}
    ], server:get_profile(Server1, UserName1)),
    % User 2 hasn't sent any messages.
    ?assertMatch([], server:get_profile(Server1, UserName2)).

% A "typical" session.
typical_session_test() ->
    initialize_test(),
    Session1 = spawn_link(?MODULE, typical_session_1, [self()]),
    Session2 = spawn_link(?MODULE, typical_session_2, [self()]),
    receive
        {Session1, ok} ->
            receive
                {Session2, ok} ->
                    done
            end
    end.

typical_session_1(TesterPid) ->
    {_, user_registered} = server:register_user(server_actor, "Alice"),
    {Server, logged_in} = server:log_in(server_actor, "Alice"),
    message_sent = server:send_message(Server, "Alice", "Hello!"),
    message_sent = server:send_message(Server, "Alice", "How is everyone?"),
    % Check own profile
    [{message, "Alice", "How is everyone?", Time2},
     {message, "Alice", "Hello!", Time1}] =
        server:get_profile(Server, "Alice"),
    ?assert(Time1 =< Time2),
    TesterPid ! {self(), ok}.

typical_session_2(TesterPid) ->
    {_, user_registered} = server:register_user(server_actor, "Bob"),
    {Server, logged_in} = server:log_in(server_actor, "Bob"),

    % Sleep one second, while Alice sends messages.
    timer:sleep(1000),

    [] = server:get_timeline(Server, "Bob"),
    followed = server:follow(Server, "Bob", "Alice"),
    [{message, "Alice", "How is everyone?", Time2},
     {message, "Alice", "Hello!", Time1}] =
        server:get_timeline(Server, "Bob"),
    ?assert(Time1 =< Time2),

    TesterPid ! {self(), ok}.
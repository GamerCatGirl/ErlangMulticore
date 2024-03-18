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
	 
	    %dict is stoted from A, B, C, ... a, b, c 
            NewUsers = orddict:store(UserName, create_user(UserName), Users),

            %When too much registered_users -> make a parallel server that handles half of the users ?
	    AmountOfUsers = orddict:size(NewUsers),
	    %Sender ! {self(), user_registered},
            
	    if AmountOfUsers > TreshHoldUsers ->
		       Range = CharEnd - CharBegin,
		       NewRange = Range div 2,
		       Split = CharBegin + NewRange,
			
		       %functie die alle users verwijderd die verplaatst moeten worden, afhankelijk van de username 
		       Filter = fun (K, V) -> 
						FirstChar = lists:nth(1, K),
						%TODO: send to the users that are splitted the new server
						Condition = FirstChar > Split,

					        %laat user nog staan tot als de user een nieuwe message stuurt en de nieuwe server terug krijgt 	
						Condition %TODO: test later of the current user deleted is 
				end,
		       ReversedFilter = fun(K, V) -> not Filter(K, V) end,

		      
			%TODO: make sure that if you have multiple with same starting letter that it somtimes also looks further than the first charachter 
		       
		      

                                            % Filter: get all where Filter is True 
	               Users2 = orddict:filter(Filter, NewUsers),
                       
	       	       FirstChar2 = lists:nth(1, UserName),

                       NewPid = initialize_with(Users2, Split + 1, CharEnd),

                       % Filter: get all where Filter is False (stay in current place)
                       MapServer = fun (K, V) ->
					FirstChar = lists:nth(1, K),
					Condition = FirstChar > Split,
					{user, Name, Subscriptions, Messages, Server} = V,

					if Condition -> {user, Name, Subscriptions, Messages, NewPid};
					true -> {user, Name, Subscriptions, Messages, Server} end 
			           end,
                       Users1 = orddict:map(MapServer, NewUsers), %TODO: dont use filter but just delete possible current user and set the rest on the different server 
		       
                      

		     	if FirstChar2 > Split ->
				      UsersWithout = orddict:erase(UserName, Users1),
				      Sender ! {NewPid, user_registered},
				      server_actor(UsersWithout, CharBegin, Split);

		       true -> 
				      Sender ! {self(), user_registered},
                                      server_actor(Users1, CharBegin, Split)

				   
			end;
                       		       %TODO: make a link between the servers to communicate with each other
		true ->
		       %SEND the server to send next messages too user 
		       Sender ! {self(), user_registered},

		       %Activate the server_actor with NewUsers
		       server_actor(NewUsers, CharBegin, CharEnd)
	   end;
	
		       
           % server_actor(NewUsers);

        {Sender, log_in, UserName} ->
	    erlang:display("Trying to log in ..." ),
	    erlang:display(UserName), 
            {user, Name, Subscriptions, Messages, NewServer} = get_user(UserName, Users),
		
	    if NewServer == undefined ->
		       Sender ! {self(), logged_in},
		       server_actor(Users, CharBegin, CharEnd);
	    true ->    Sender ! {NewServer, logged_in},
	       	       NewUsers = orddict:erase(UserName, Users),		
	               server_actor(NewUsers, CharBegin, CharEnd) end;

            % This doesn't do anything, but you could use this operation if needed.
          
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
    {user, UserName, sets:new(), [], undefined}.

% Get user with `UserName` in `Users`.
% Throws an exception if user does not exist (to help in debugging).
% In your project, you do not need specific error handling for users that do not exist;
% you can assume that all users that use the system exist.
get_user(UserName, Users) ->
    case orddict:find(UserName, Users) of
        {ok, User} -> User;
        error -> throw({user_not_found, UserName})
    end.

% Update `Users` so `UserName` follows `UserNameToFollow`.
follow(Users, UserName, UserNameToFollow) ->
    {user, Name, Subscriptions, Messages, Server} = get_user(UserName, Users),
    NewUser = {user, Name, sets:add_element(UserNameToFollow, Subscriptions), Messages, Server},
    orddict:store(UserName, NewUser, Users).

% Modify `Users` to store `Message`.
store_message(Users, Message) ->
    {message, UserName, _MessageText, _Timestamp} = Message,
    {user, Name, Subscriptions, Messages, Server} = get_user(UserName, Users),
    NewUser = {user, Name, Subscriptions, Messages ++ [Message], Server},
    orrdict:store(UserName, NewUser, Users).

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


    UserNames = ["A", "B", "C", "D", "W", "X", "Y", "Z"],

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

    erlang:display(Server1),
    erlang:display(Server2),
    erlang:display(Server3),
    erlang:display(Server4),
    erlang:display(Server5),
    erlang:display(Server6),
    erlang:display(Server7),
    erlang:display(Server8),


    ?assertMatch(user_registered, Response1),
    ?assertMatch(user_registered, Response2),
    ?assertMatch(user_registered, Response3),
    ?assertMatch(user_registered, Response4),
    ?assertMatch(user_registered, Response5),
    ?assertMatch(user_registered, Response6),
    ?assertMatch(user_registered, Response7),
    ?assertMatch(user_registered, Response8),
    erlang:display("Users succesfully registered: "),
    [UserName1, Server1, UserName2, Server2, UserName3, Server3, UserName4, Server4, UserName5, Server5, UserName6, Server6, UserName7, Server7, UserName8, Server8].

    % Test log in.
log_in_test() ->
    erlang:display("Logging in users..."),
    [UserName1, Server1, UserName2, Server2, UserName3, Server3, UserName4, Server4, UserName5, Server5, UserName6, Server6, UserName7, Server7, UserName8, Server8 | _] = register_user_test(),
    erlang:display(Server1),
    erlang:display(UserName1),
   
   

    {NewServer1, Response1} = server:log_in(Server1, UserName1),
    {NewServer5, Response5} = server:log_in(Server5, UserName5),
    {NewServer8, Response8} = server:log_in(Server8, UserName8),

    ?assertMatch(logged_in, Response1),
    ?assertMatch(logged_in, Response5),
    ?assertMatch(logged_in, Response8),
    [UserName1, NewServer1, UserName5, NewServer5, UserName8, NewServer8].
  
    % Note: returned pids _Server1 and _Server2 do not necessarily need to be
    % the same.

% Test follow: user 1 will follow 2 and 3.
follow_test() ->
    erlang:display("Following users ..."),
    [UserName1, NewServer1, UserName5, NewServer5, UserName8, NewServer8 | _] =  log_in_test(),


    ?assertMatch(followed, server:follow(NewServer1, UserName1, UserName5)),
    ?assertMatch(followed, server:follow(NewServer1, UserName1, UserName8)),
    ?assertMatch(followed, server:follow(NewServer5, UserName5, UserName8)),
    {UserName1, NewServer1, [UserName5, UserName8]}.

% Test sending a message.
send_message_test() ->
    erlang:display("Messaging users ..."),
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

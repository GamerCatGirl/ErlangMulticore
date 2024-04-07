%% This is a simple implementation of the project, using one server process.
%%
%% It will create one "server" actor that contains all internal state (users,
%% their subscriptions, and their messages).
%%
%% This implementation is provided with unit tests, however, these tests are
%% neither complete nor implementation independent, so be careful when reusing
%% them.
-module(server_parallelized_new).

-include_lib("eunit/include/eunit.hrl").

-export([initialize_with/2, server_actor/2, typical_session_1/1, initialize_new/1,
    typical_session_2/1, register_and_redirect/3]).

%%
%% Additional API Functions
%%
%%
initialize_new(TreshHoldUsers) ->
	PiDs = orddict:new(),
	PiDtoFill = none, 
	ServerName = register_and_redirect,

	ServerPid = spawn_link(?MODULE, ServerName, [PiDs, PiDtoFill, TreshHoldUsers]),


	catch unregister(ServerName),

	register(ServerName, ServerPid),

	ServerPid.


% Start server.
initialize(PiD) ->
    initialize_with(orddict:new(), PiD).

% Start server with an initial state.
% Useful for benchmarking.
initialize_with(Users, PidInit) ->
    ServerPid = spawn_link(?MODULE, server_actor, [Users, PidInit]),
   
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

activate_new_server(UserName, Sender, PidInit) ->
	Pid = initialize(PidInit),
	Pid ! {Sender, register_user, UserName},
	{Pid, 1}.

register_user(PiDtoFill, UserName, TreshHoldUsers, Sender, PiDinit) ->
	{Pid, AmountOfUsers} = PiDtoFill,
	
	if AmountOfUsers == TreshHoldUsers ->  activate_new_server(UserName, Sender, PiDinit);
	true ->   Pid ! {Sender, register_user, UserName},	
		  {Pid ,AmountOfUsers + 1} end.


add_user_to_PIDS(UserName,NewPid ,PiDs) ->
	orddict:store(UserName, NewPid, PiDs).



register_and_redirect(PiDs, PiDtoFill, TreshHoldUsers) ->

	% PiDs = orddict({U, P}, {U, P})
	% PiD to fill = PiD that is not full yet
	
	receive

                {stop} ->
			orddict:map( fun(_, V) -> V ! {stop} end, PiDs);
		{print} ->
			erlang:display("Printing init server ..."),
			erlang:display(PiDs);

		{Sender, register_user, UserName} ->
			% Check if there is an active server to fill otherwise make one and add the user
			NewPidtoFill = if (PiDtoFill == none) ->  activate_new_server(UserName, Sender, self());
			% Active server -> Add the user in it or make new server when threshold is met 
		   	               true -> register_user(PiDtoFill, UserName, TreshHoldUsers, Sender, self()) end,
			% Add the user in an ordered dictionary with its server id
			{NewPid, _} = NewPidtoFill,
			NewPiDs = add_user_to_PIDS(UserName, NewPid, PiDs),
			% Make the server back available for new requests 
			register_and_redirect(NewPiDs, NewPidtoFill, TreshHoldUsers);

		{Sender, get_profile, UserName} ->
			erlang:display("TODO");


	         {Sender, follow, UserName, UserNameToFollow} ->
			%Get server id of user to follow 
			PiDuserNameToFollow = orddict:fetch(UserNameToFollow, PiDs),
			%Let user know it gets a new follower 
			PiDuserNameToFollow ! {Sender, new_follower, UserNameToFollow, UserName},
			%Send back to the follower the server id 
			Sender ! PiDuserNameToFollow,
			%Make server back available
			register_and_redirect(PiDs, PiDtoFill, TreshHoldUsers)
	        
	end.


newFollower(UserName, UserNameToFollow, RedirectServer) ->
	RedirectServer ! {self(), follow, UserName, UserNameToFollow},
	receive
		ServerIDFollowing -> ServerIDFollowing
	end.

follow(Users, UserName, UserNameToFollow, ServerToFollow) ->
    {user, Name, TimeLine, Messages, Followers} = get_user(UserName, Users),
    NewSubscriptions = orddict:store(UserNameToFollow, {ServerToFollow, []}, TimeLine),
    NewUser = {user, Name, NewSubscriptions, Messages, Followers},
    orddict:store(UserName, NewUser, Users).

%Client to server 
server_actor(Users, RedirectServer) ->
    receive
% When message received, spawn new
        {stop} -> ok;
%
        {Sender, register_user, UserName} ->
            NewUsers = orddict:store(UserName, create_user(UserName), Users),
            Sender ! {self(), user_registered},
	    server_actor(NewUsers, RedirectServer);

	{Sender, print} ->
	    erlang:display("PiD"),
	    erlang:display(self()),
	    erlang:display("Users"),
	    erlang:display(orddict:fetch_keys(Users)),
	    Sender ! {self(), printed},
	    server_actor(Users, RedirectServer);

        {Sender, log_in, _UserName} ->
            % This doesn't do anything, but you could use this operation if needed.
            Sender ! {self(), logged_in},
            server_actor(Users, RedirectServer);

        {Sender, follow, UserName, UserNameToFollow} ->
            newFollower(UserName, UserNameToFollow, RedirectServer),
            %NewUsers = follow(Users, UserName, UserNameToFollow, ServerIDFollowing),
            Sender ! {self(), followed},
            server_actor(Users, RedirectServer);

        {Sender, send_message, UserName, MessageText, Timestamp} ->
            NewUsers = store_message(Users, {message, UserName, MessageText, Timestamp}, Sender),
            %Sender ! {self(), message_sent},
            server_actor(NewUsers, RedirectServer);


	{Sender, receive_message, ToUsername, FromUsername, Message} ->
		
		{user, ToUsername, TimeLine, Messages, FollowedBy} = get_user(ToUsername, Users),

		%save messages in an ordered dictionary on time so they don't need to be sorted -> sort takes lots of time
		NewMessagesList = lists:map(fun(Elm) ->
							    {message, _, _, T} = Elm,
							    NegativeT = 0 - T, 
							    {NegativeT, [Elm]} end
						    , Message),

		NewMessages = orddict:from_list(NewMessagesList),

		NewTimeLine = orddict:merge(fun(_, V1, V2) -> V1 ++ V2 end, TimeLine, NewMessages),
		
		NewUser = {user, ToUsername, NewTimeLine, Messages, FollowedBy},
		NewUsers = orddict:store(ToUsername, NewUser, Users),
                Sender ! {self(), message_sent},
		server_actor(NewUsers, RedirectServer);

        {Sender, get_timeline, UserName} ->
           
            
	    SortedMessages = timeline(Users, UserName),

            Sender ! {self(), timeline, UserName, SortedMessages},
            server_actor(Users, RedirectServer);



            %Sender ! {self(), timeline, UserName, timeline(Users, UserName)},
            %server_actor(Users);

        {Sender, get_profile, UserName} ->
            Sender ! {self(), profile, UserName, sort_messages(get_messages(Users, UserName))},
            server_actor(Users, RedirectServer);

	{Sender, new_follower, UserName, Follower} ->

	    {user, UserName, Subscriptions, Messages, FollowedBy} = get_user(UserName, Users),
	    Sender ! {self(), receive_message, Follower, UserName, Messages},

	    NewFollowedBy = sets:add_element({Follower, Sender} , FollowedBy),
	    NewUser = {user, UserName, Subscriptions, Messages, NewFollowedBy},
	    NewUsers = orddict:store(UserName, NewUser, Users),
	    server_actor(NewUsers, RedirectServer)
    end.

%%
%% Internal Functions
%%

% Create a new user with `UserName`.
create_user(UserName) ->
    %user, Username, TimeLine, Messages, FollowedBy 
    {user, UserName, orddict:new(), [], sets:new()}. 

% Get user with `UserName` in `Users`.
% Throws an exception if user does not exist (to help in debugging).
% In your project, you do not need specific error handling for users that do not exist;
% you can assume that all users that use the system exist.
get_user(UserName, Users) ->
    case orddict:find(UserName, Users) of
        {ok, User} -> User;
        error -> throw({user_not_found, UserName})
    end.


% Modify `Users` to store `Message`.
store_message(Users, Message, Sender) ->
    {message, UserName, _MessageText, _Timestamp} = Message,
    {user, Name, Subscriptions, Messages, FollowedBy} = get_user(UserName, Users),
    %Send message to followers

    sets:fold(fun({UN, SERVER}, _) -> 
		   SERVER ! {Sender, receive_message, UN, UserName, [Message]}

	      end,
	      [],
	      FollowedBy),

    NoFollowers = sets:is_empty(FollowedBy),
 

    if NoFollowers -> Sender ! {self(), message_sent};
    true -> done end,


    NewUser = {user, Name, Subscriptions, Messages ++ [Message], FollowedBy},
    orddict:store(UserName, NewUser, Users).

% Get all messages by `UserName`.
get_messages(Users, UserName) ->
    {user, _, _, Messages, _} = get_user(UserName, Users),
    Messages.

% Generate timeline for `UserName`.
timeline(Users, UserName) ->
    {user, _, TimeLine, _, _} = get_user(UserName, Users),

    ListTimeline = orddict:to_list(TimeLine),
    FlattenTimeline = lists:flatmap(fun({_, V}) -> V end, ListTimeline),
    FlattenTimeline.

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
    TreshHoldUsers = 1,
    catch unregister(register_and_redirect),
    initialize_new(TreshHoldUsers).

% Initialize server and test user registration of 4 users.
% Returns list of user names to be used in subsequent tests.
register_user_test() ->
    io:write("Registering users..."),
    PID  = initialize_test(),

    UN1 = "A",
    UN2 = "B",
    UN3 = "C",
    UN4 = "D",

    % RESP short for response 
    USER1RESP = server:register_user(PID, UN1), 
    USER2RESP = server:register_user(PID, UN2),
    USER3RESP = server:register_user(PID, UN3),
    USER4RESP = server:register_user(PID, UN4),

    ?assertMatch({_, user_registered}, USER1RESP),
    ?assertMatch({_, user_registered}, USER2RESP),
    ?assertMatch({_, user_registered}, USER3RESP),
    ?assertMatch({_, user_registered}, USER4RESP),

    {SERVER1, _} = USER1RESP,
    {SERVER2, _} = USER2RESP, 
    {SERVER3, _} = USER3RESP,
    {SERVER4, _} = USER4RESP,

    RegisteredUsers = [{SERVER1, UN1}, {SERVER2, UN2}, {SERVER3, UN3}, {SERVER4, UN4}],

    RegisteredUsers.

% Test log in.
log_in_test() ->
    [{SERVER1, UN1}, {SERVER2, UN2} | _] = register_user_test(),
    ?assertMatch({_Server1, logged_in}, server:log_in(SERVER1, UN1)),
    ?assertMatch({_Server2, logged_in}, server:log_in(SERVER2, UN2)).
    % Note: returned pids _Server1 and _Server2 do not necessarily need to be
    % the same.

% Test follow: user 1 will follow 2 and 3.
follow_test() ->
    [{SERVER1, UN1}, {SERVER2, UN2}, {SERVER3, UN3}, {SERVER4, UN4}] = register_user_test(),
    server:log_in(server_actor, UN1),
    ?assertMatch(followed, server:follow(SERVER1, UN1, UN2)),
    ?assertMatch(followed, server:follow(SERVER1, UN1, UN3)),
     [{SERVER1, UN1}, {SERVER2, UN2}, {SERVER3, UN3}, {SERVER4, UN4}] .

% Test sending a message.
send_message_test() ->
    [{SERVER1, UN1}, {SERVER2, UN2}, {SERVER3, UN3}, {SERVER4, UN4}] = follow_test(),
    SERVER1 ! {self(), print},
    ?assertMatch(message_sent,
        server:send_message(SERVER1, UN1, "Hello!")),
    ?assertMatch(message_sent,
        server:send_message(SERVER1, UN1, "How is everyone?")),
    [{SERVER1, UN1}, {SERVER2, UN2}, {SERVER3, UN3}, {SERVER4, UN4}] .

% Test getting a timeline.
get_timeline_test() ->
    [{SERVER1, UN1}, {SERVER2, UN2}, {SERVER3, UN3}, {SERVER4, UN4}]  = follow_test(),

    % When nothing has been sent, the timeline is empty.
    TU1 = server:get_timeline(SERVER1, UN1),
    ?assertMatch([], TU1),

    ?assertMatch(message_sent,
        server:send_message(SERVER2, UN2, "Hello I'm B!")),

    % One message in the timeline.
    ?assertMatch([
        {message, UN2, "Hello I'm B!", _TimeB1}
    ], server:get_timeline(SERVER1, UN1)),

    ?assertMatch(message_sent,
        server:send_message(SERVER2, UN2, "How is everyone?")),
    ?assertMatch(message_sent,
        server:send_message(SERVER3, UN3, "Hello I'm C!")),

    % All three messages in the timeline, newest first.
    ?assertMatch([
        {message, UN3, "Hello I'm C!", _TimeC1},
        {message, UN2, "How is everyone?", _TimeB2},
        {message, UN2, "Hello I'm B!", _TimeB1}
    ], server:get_timeline(SERVER1, UN1)),

    % User 2 does not follow any so gets an empty timeline.
    ?assertMatch([], server:get_timeline(SERVER2, UN2)).

% Test getting the profile.
get_profile_test() ->
     [{SERVER1, UN1}, {SERVER2, UN2}, {SERVER3, UN3}, {SERVER4, UN4}]  = send_message_test(),
    % Most recent message is returned first.
    ?assertMatch([
        {message, UN1, "How is everyone?", _TimeA2},
        {message, UN1, "Hello!", _TimeA1}
    ], server:get_profile(SERVER1, UN1)),
    % User 2 hasn't sent any messages.
    ?assertMatch([], server:get_profile(SERVER2, UN2)).

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
    {Server, user_registered} = server:register_user(register_and_redirect, "Alice"),
    {_, logged_in} = server:log_in(Server, "Alice"),
    message_sent = server:send_message(Server, "Alice", "Hello!"),
    message_sent = server:send_message(Server, "Alice", "How is everyone?"),
    % Check own profile
    [{message, "Alice", "How is everyone?", Time2},
     {message, "Alice", "Hello!", Time1}] =
        server:get_profile(Server, "Alice"),
    ?assert(Time1 =< Time2),
    TesterPid ! {self(), ok}.

typical_session_2(TesterPid) ->
    {Server, user_registered} = server:register_user(register_and_redirect, "Bob"),
    {_, logged_in} = server:log_in(Server, "Bob"),

    % Sleep one second, while Alice sends messages.
    timer:sleep(1000),

    [] = server:get_timeline(Server, "Bob"),
    followed = server:follow(Server, "Bob", "Alice"),
    TimeLineBob = server:get_timeline(Server, "Bob"),
    [{message, "Alice", "How is everyone?", Time2},
     {message, "Alice", "Hello!", Time1}] =
        TimeLineBob,
    ?assert(Time1 =< Time2),

    TesterPid ! {self(), ok}.


stop_all_test() ->
	PID = initialize_new(1),
	server:register_user(PID, "A"),
	server:register_user(PID, "B"),
	server:register_user(PID, "C"),
        server:register_user(PID, "D"),
	server:register_user(PID, "E"),
	server:register_user(PID, "F"),
	PID ! {print},
	PID ! {stop},
	PID ! {print},

	PID2 = initialize_new(2),
        server:register_user(PID2, "A"),
	server:register_user(PID2, "B"),
	server:register_user(PID2, "C"),
        server:register_user(PID2, "D"),
	server:register_user(PID2, "E"),
	server:register_user(PID2, "F"),
	PID2 ! {stop},

        PID6 = initialize_new(6),
        server:register_user(PID6, "A"),
	server:register_user(PID6, "B"),
	server:register_user(PID6, "C"),
        server:register_user(PID6, "D"),
	server:register_user(PID6, "E"),
	server:register_user(PID6, "F"),
	PID6 ! {stop}.





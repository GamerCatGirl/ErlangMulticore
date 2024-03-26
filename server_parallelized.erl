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

-export([initialize/0, initialize_with/4, server_actor/5, typical_session_1/1,
    typical_session_2/1]).

%%
%% Additional API Functions
%%

% Start server.
initialize() ->
    EmptyDict = orddict:new(),
    BeginChar = 33,
    EndChar = 126,
    initialize_with(EmptyDict, BeginChar, EndChar, EmptyDict). %username without extended ascii 

% Start server with an initial state.
% Useful for benchmarking.
initialize_with(Users, CharBegin, CharEnd, PiDs) ->
    UsersToBeReplaced = orddict:new(),
    ServerPid = spawn_link(?MODULE, server_actor, [Users, CharBegin, CharEnd, PiDs, UsersToBeReplaced]),
    %TODO: setup PIDS SERVER 
    catch unregister(server_actor),
    register(server_actor, ServerPid),
    server:setup(ServerPid),
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
server_actor(Users, CharBegin, CharEnd, PiDs, UsersToBeReplaced) ->
    TreshHoldUsers = 5, %differ this to test the parallel process 
    receive
% When message received, spawn newest
        {Sender, print} ->
		    erlang:display("PiD"),
		    erlang:display(self()),
		    erlang:display("Users"),
		    erlang:display(orddict:fetch_keys(Users)),
		    Sender ! {self(), printed},
		    server_actor(Users, CharBegin, CharEnd, PiDs, UsersToBeReplaced);

	{Sender, setup} ->
		%Begin = ,
		NewPiDs = orddict:store(CharEnd, self(), PiDs),

		Sender ! {self(), setup_completed},


		server_actor(Users, CharBegin, CharEnd, NewPiDs, UsersToBeReplaced);

        {Sender, register_user, UserName} ->

	 
	    %dict is stoted from A, B, C, ... a, b, c 
            NewUsers = orddict:store(UserName, create_user(UserName), Users),
            FirstCharUser = lists:nth(1, UserName),


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
						Condition = FirstChar =< Split,

					        %laat user nog staan tot als de user een nieuwe message stuurt en de nieuwe server terug krijgt 	
						Condition %TODO: test later of the current user deleted is 
				end,
		       ReversedFilter = fun(K, V) -> not Filter(K, V) end,

		      
			%TODO: make sure that if you have multiple with same starting letter that it somtimes also looks further than the first charachter 
		       
		      

	               UsersSmallANSII = orddict:filter(Filter, NewUsers), %Alle users die <= Split 
                       
		       NewPid = initialize_with(UsersSmallANSII, CharBegin, Split, PiDs),

                       % Filter: get all where Filter is False (stay in current place)
                       MapServer = fun (K, V) ->
					FirstChar = lists:nth(1, K), % Key eerste Character 
					{user, Name, Subscriptions, Messages, Server} = V,

					if (FirstChar =< Split) -> NewPid;
					true -> {user, Name, Subscriptions, Messages, Server} end 
			           end,
		       UsersToBeReplacedWithoutNewPid = orddict:filter(Filter, NewUsers),
		       UsersToBeReplacedNew = orddict:map(MapServer, UsersToBeReplacedWithoutNewPid),
		
		     
                       UsersBigANSII = orddict:filter(ReversedFilter, NewUsers), %TODO: dont use filter but just delete possible current user and set the rest on the different server 
		     
                      
                        NewPids = orddict:store(Split, NewPid, PiDs),

		     	if FirstCharUser =< Split ->
						      
				      UsersWithout = orddict:erase(UserName, UsersToBeReplaced), 
				      Sender ! {NewPid, user_registered},
				      server_actor(UsersWithout, Split + 1, CharEnd, NewPids, UsersToBeReplacedNew);
			
		       true ->	     
				      Sender ! {self(), user_registered},
                                      server_actor(UsersBigANSII, Split + 1, CharEnd, NewPids, UsersToBeReplacedNew)

				   
			end;
		true ->
		       if (FirstCharUser < CharBegin) or (FirstCharUser > CharEnd) ->
				 
				   Key = getKeyServer(UserName, PiDs),
				   {Response, Value} = orddict:find(Key, PiDs),
				  % {ServerSend, Response} =
			
				   server:register_user(Value, UserName),
			
				   Sender ! {Value, user_registered};
			true -> Sender ! {self(), user_registered} end,	  

		       %if ()

		       %SEND the server to send next messages too user 
		       %Sender ! {self(), user_registered},

		       %Activate the server_actor with NewUsers
		       server_actor(NewUsers, CharBegin, CharEnd, PiDs, UsersToBeReplaced)
	   end;
	
		       
           % server_actor(NewUsers);

        {Sender, log_in, UserName} ->
		    UserKeys = orddict:fetch_keys(Users),
		 
                    

		   case orddict:find(UserName, Users) of
        		{ok, User} ->  
				    Sender ! {self(), logged_in},
		                    server_actor(Users, CharBegin, CharEnd, PiDs, UsersToBeReplaced);
				  
        		error ->  case orddict:find(UserName, UsersToBeReplaced) of 
					  {ok, NewServer} ->  Sender ! {NewServer, logged_in},
	       	       					      NewUsersToBeReplaced = orddict:erase(UserName, UsersToBeReplaced),		
	               					server_actor(Users, CharBegin, CharEnd, PiDs, NewUsersToBeReplaced);

					  error -> throw({user_not_found, UserName}) 
				  end 
		   end;

		

		    %if (Message == ok) -> erlang:display("User found");
		    %   true -> orddict:find(UserName, UsersToBeReplaced), 
		    %           erlang:display("User not found") end,
                 
	    
     
            % This doesn't do anything, but you could use this operation if needed.
          
        {Sender, follow, UserName, UserNameToFollow, ServerToFollow} ->
		KeyUser = getKeyServer(UserNameToFollow, PiDs),
	        {Response, Value} = orddict:find(KeyUser, PiDs), 



	    %ServerToFollow = getServerUser(UserNameToFollow, PiDs),
	    %erlang:display("Server To Follow: "),
	    %erlang:display(ServerToFollow),	

            NewUsers = follow(Users, UserName, UserNameToFollow, ServerToFollow),
            Sender ! {self(), followed},
            server_actor(NewUsers, CharBegin, CharEnd, PiDs, UsersToBeReplaced);

        {Sender, send_message, UserName, MessageText, Timestamp} ->
            NewUsers = store_message(Users, {message, UserName, MessageText, Timestamp}),
            Sender ! {self(), message_sent},
            server_actor(NewUsers, CharBegin, CharEnd, PiDs, UsersToBeReplaced);

	{Sender, get_messages, UserName} ->
		Messages = get_messages(Users, UserName),
		Sender ! {self(), messages_received, Messages},
		server_actor(Users, CharBegin, CharEnd, PiDs, UsersToBeReplaced);

        {Sender, get_timeline, UserName} ->
            Sender ! {self(), timeline, UserName, timeline(Users, UserName)},
            server_actor(Users, CharBegin, CharEnd, PiDs, UsersToBeReplaced);


        {Sender, get_profile, UserName} ->
            Sender ! {self(), profile, UserName, sort_messages(get_messages(Users, UserName))},
            server_actor(Users, CharBegin, CharEnd, PiDs, UsersToBeReplaced)
    end.

%%
%% Internal Functions
%%
%%

getKeyServer(UserName, PiDs) ->
	Keys = orddict:fetch_keys(PiDs),
	Char = lists:nth(1, UserName),

	Pred = fun(X) ->       
			       Char < X end,
        KeyList = lists:filter(Pred, Keys),
	lists:nth(1, KeyList).

% Create a new user with `UserName`.
create_user(UserName) ->
    {user, UserName, sets:new(), [], undefined}.

% Get user with `UserName` in `Users`.
% Throws an exception if user does not exist (to help in debugging).
% In your project, you do not need specific error handling for users that do not exist;
% you can assume that all users that use the system exist.
get_user(UserName, Users) ->
    case orddict:find(UserName, Users) of
        {ok, User} -> 
		    User;
        error -> throw({user_not_found, UserName})
    end.

% Update `Users` so `UserName` follows `UserNameToFollow`.
follow(Users, UserName, UserNameToFollow) ->
    {user, Name, Subscriptions, Messages, Server} = get_user(UserName, Users),
    NewUser = {user, Name, sets:add_element(UserNameToFollow, Subscriptions), Messages, Server},
    orddict:store(UserName, NewUser, Users).

follow(Users, UserName, UserNameToFollow, ServerToFollow) ->
    {user, Name, Subscriptions, Messages, Server} = get_user(UserName, Users),
    NewUser = {user, Name, sets:add_element({UserNameToFollow, ServerToFollow}, Subscriptions), Messages, Server},

    orddict:store(UserName, NewUser, Users).


% Modify `Users` to store `Message`.
store_message(Users, Message) ->

    {message, UserName, _MessageText, _Timestamp} = Message,
    {user, Name, Subscriptions, Messages, Server} = get_user(UserName, Users),
    NewUser = {user, Name, Subscriptions, Messages ++ [Message], Server},

    orddict:store(UserName, NewUser, Users).
 
% Get all messages by `UserName`.
get_messages(Users, UserName) ->
    {user, _, _, Messages, Server} = get_user(UserName, Users),
    Messages.

% Generate timeline for `UserName`.
timeline(Users, UserName) ->

    {user, _, Subscriptions, _, _} = get_user(UserName, Users),

    UnsortedMessagesForTimeLine =
        lists:foldl(fun({FollowedUserName, ServerFollower}, AllMessages) ->

			
			Messages = if ServerFollower == self() ->
				   	get_messages(Users, FollowedUserName);
				   true -> server:get_messages(ServerFollower, FollowedUserName) end,

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



    ?assertMatch(user_registered, Response1),
    ?assertMatch(user_registered, Response2),
    ?assertMatch(user_registered, Response3),
    ?assertMatch(user_registered, Response4),
    ?assertMatch(user_registered, Response5),
    ?assertMatch(user_registered, Response6),
    ?assertMatch(user_registered, Response7),
    ?assertMatch(user_registered, Response8),

    Servers = [Server1, Server2, Server3, Server4, Server5, Server6, Server7, Server8],

    erlang:display("Server Register:"),
    erlang:display(Servers),

    server:printServer(Server1),
    server:printServer(Server8),

    [UserName1, Server1, UserName2, Server2, UserName3, Server3, UserName4, Server4, UserName5, Server5, UserName6, Server6, UserName7, Server7, UserName8, Server8].

    % Test log in.
log_in_test() ->
  
    [UserName1, Server1, UserName2, Server2, UserName3, Server3, UserName4, Server4, UserName5, Server5, UserName6, Server6, UserName7, Server7, UserName8, Server8 | _] = register_user_test(),

    {NewServer1, Response1} = server:log_in(Server1, UserName1),
    {NewServer2, Response2} = server:log_in(Server2, UserName2),
    {NewServer3, Response3} = server:log_in(Server3, UserName3),
    {NewServer4, Response4} = server:log_in(Server4, UserName4),
    {NewServer5, Response5} = server:log_in(Server5, UserName5),
    {NewServer6, Response6} = server:log_in(Server6, UserName6),
    {NewServer7, Response7} = server:log_in(Server7, UserName7),
    {NewServer8, Response8} = server:log_in(Server8, UserName8),

    ?assertMatch(logged_in, Response1),
    ?assertMatch(logged_in, Response5),
    ?assertMatch(logged_in, Response8),

    Servers = [NewServer1, NewServer2, NewServer3, Server4, NewServer5, Server6, Server7, NewServer8],

    erlang:display("Server log in:"),
    erlang:display(Servers),

   
    [UserName1, NewServer1, UserName5, NewServer5, UserName8, NewServer8].
  
    % Note: returned pids _Server1 and _Server2 do not necessarily need to be
    % the same.

% Test follow: user 1 will follow 2 and 3.
follow_test() ->

    [UserName1, NewServer1, UserName5, NewServer5, UserName8, NewServer8 | _] =  log_in_test(),


    ?assertMatch(followed, server:follow(NewServer1, UserName1, NewServer5, UserName5)),
    ?assertMatch(followed, server:follow(NewServer1, UserName1, NewServer8, UserName8)),
    %?assertMatch(followed, server:follow(NewServer5, UserName5, NewServer8, UserName8)),
    {UserName1, NewServer1, [UserName5, NewServer5, UserName8, NewServer8]}.

% Test sending a message.
send_message_test() ->
   
    {UserName1, Server1, Subscriptions} = follow_test(),
    Response1 = server:send_message(Server1, UserName1, "Hello!"),
    Response2 = server:send_message(Server1, UserName1, "How is everyone?"),

    ?assertMatch(message_sent, Response1),
    ?assertMatch(message_sent, Response2),
    {UserName1, Server1, Subscriptions}.

% Test getting a timeline.
get_timeline_test() ->
    {UserName1, Server1, [UserName5, Server5, UserName8, Server8]} = follow_test(),

    TimeLine1 = server:get_timeline(Server1, UserName1),
  
    % When nothing has been sent, the timeline is empty.
    ?assertMatch([], TimeLine1),

    ?assertMatch(message_sent,
        server:send_message(Server5, UserName5, "Hello I'm B!")),

    % One message in the timeline.
    ?assertMatch([
        {message, UserName5, "Hello I'm B!", _TimeB1}
    ], server:get_timeline(Server1, UserName1)),

    ?assertMatch(message_sent,
        server:send_message(Server8, UserName5, "How is everyone?")),
    ?assertMatch(message_sent,
        server:send_message(Server8, UserName8, "Hello I'm C!")),

    % All three messages in the timeline, newest first.
    ?assertMatch([
        {message, UserName8, "Hello I'm C!", _TimeC1},
        {message, UserName5, "How is everyone?", _TimeB2},
        {message, UserName5, "Hello I'm B!", _TimeB1}
    ], server:get_timeline(Server1, UserName1)),

    % User 2 does not follow any so gets an empty timeline.
    TimeLine9 = server:get_timeline(Server5, UserName5),

    ?assertMatch([], server:get_timeline(Server5, UserName5)).
   

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
    CharBegin = 32,
    CharEnd = 126,
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

    RegisterUser = server:register_user(server_actor, "Alice"),

    {ServerA, user_registered} = RegisterUser,
    LoggedInUser = server:log_in(ServerA, "Alice"),
    {Server, logged_in} = LoggedInUser, 
    message_sent = server:send_message(Server, "Alice", "Hello!"),
    message_sent = server:send_message(Server, "Alice", "How is everyone?"),
  
    % Check own profile
    [{message, "Alice", "How is everyone?", Time2},
     {message, "Alice", "Hello!", Time1}] =
        server:get_profile(ServerA, "Alice"),

    ?assert(Time1 =< Time2),
   
    TesterPid ! {self(), ok}.

typical_session_2(TesterPid) ->
 
    {ServerB, user_registered} = server:register_user(server_actor, "Bob"),
    {Server, logged_in} = server:log_in(ServerB, "Bob"),

    % Sleep one second, while Alice sends messages.
    timer:sleep(1000),

    [] = server:get_timeline(Server, "Bob"),
 
    followed = server:follow(Server, "Bob", Server, "Alice"),
 
    TimeLine = server:get_timeline(Server, "Bob"),
 
    [{message, "Alice", "How is everyone?", Time2},
     {message, "Alice", "Hello!", Time1}] =
        TimeLine,
    ?assert(Time1 =< Time2),

    TesterPid ! {self(), ok}.

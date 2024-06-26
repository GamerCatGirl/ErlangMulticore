%% This module provides the protocol that is used to interact with an
%% implementation of a microblogging service.
%%
%% The interface is design to be synchronous: it waits for the reply of the
%% system.
%%
%% This module defines the public API that is supposed to be used for
%% experiments. The semantics of the API here should remain unchanged.
-module(server).

-export([register_user/2,
         log_in/2,
         follow/3,
	 follow/4,
         get_timeline/2,
	 printServer/1,
	 setup/1,
         get_profile/2,
	 get_messages/2,
         send_message/3]).

%%
%% Server API
%%

-spec setup(pid()) -> {pid(), setup_completed}.
setup(ServerPid) ->
	ServerPid ! {self(), setup},
	receive
		{ResponsePid, setup_completed} ->
			{ResponsePid, setup_completed}
	end.


-spec printServer(pid()) -> {pid(), printed}.
printServer(ServerPid) ->
	ServerPid ! {self(), print},
	receive
		{ResponsePid, printed} ->
			{ResponsePid, printed}
	end.

% Register a new user.
%
% Returns a pid that should be used for subsequent requests by this client.
-spec register_user(pid(), string()) -> {pid(), user_registered}.
register_user(ServerPid, UserName) ->
    ServerPid ! {self(), register_user, UserName},
    receive
        {ResponsePid, user_registered} ->
            {ResponsePid, user_registered}
    end.

% Log in.
% For simplicity, we do not request a password: authorization and security are
% not regarded in any way.
%
% Returns a pid that should be used for subsequent requests by this client.
-spec log_in(pid(), string()) -> {pid(), logged_in}.
log_in(ServerPid, UserName) ->
    ServerPid ! {self(), log_in, UserName},
    receive
        {ResponsePid, logged_in} ->
            {ResponsePid, logged_in}
    end.

% Follow another user.
-spec follow(pid(), string(), string()) -> followed.
follow(ServerPid, UserName, UserNameToFollow) ->
    ServerPid ! {self(), follow, UserName, UserNameToFollow},
    receive
        {_ResponsePid, followed} -> followed
    end.

% Follow parallel another user 
-spec follow(pid(), string(), pid(), string()) -> followed.
follow(ServerPid, UserName, ServerToFollow, UserNameToFollow) ->
    ServerPid ! {self(), follow, UserName, UserNameToFollow, ServerToFollow},
    receive
        {_ResponsePid, followed} -> followed
    end.

% Send a message for a user.
% (Authorization/security are not regarded in any way.)
-spec send_message(pid(), string(), string()) -> message_sent.
send_message(ServerPid, UserName, MessageText) ->
    ServerPid ! {self(), send_message, UserName, MessageText, os:system_time()},
    receive
        {_ResponsePid, message_sent} ->
            message_sent
    end.


% Get messages of a user 
-spec get_messages(pid(), string()) -> message_received.
get_messages(ServerPid, UserName) ->
	ServerPid ! {self(), get_messages, UserName},
	receive
		{_ResponsePid, message_received, Messages} ->
			Messages;
                {_, Response, Messages} ->
			erlang:display("Response"),
			erlang:display(Response)
	end.

% Request the timeline of a user.
-spec get_timeline(pid(), string()) -> [{message, integer(), erlang:timestamp(), string()}].
get_timeline(ServerPid, UserName) ->
    ServerPid ! {self(), get_timeline, UserName},
    receive
        {_ResponsePid, timeline, UserName, Timeline} ->
            Timeline
    end.

% Request the profile of a user.
% This returns a list of messages by the user.
-spec get_profile(pid(), string()) -> [{message, integer(), erlang:timestamp(), string()}].
get_profile(ServerPid, UserName) ->
    ServerPid ! {self(), get_profile, UserName},
    receive
        {_ResponsePid, profile, UserName, Messages} ->
            Messages
    end.

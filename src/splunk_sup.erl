%%%-------------------------------------------------------------------
%%% @author Zachary Kessin <>
%%% @copyright (C) 2013, Zachary Kessin
%%% @doc
%%%
%%% @end
%%% Created : 18 Feb 2013 by Zachary Kessin <>
%%%-------------------------------------------------------------------
-module(splunk_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%%===================================================================
%%% API functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
%%
%% @spec init(Args) -> {ok, {SupFlags, [ChildSpec]}} |
%%                     ignore |
%%                     {error, Reason}
%% @end
%%--------------------------------------------------------------------
init([]) ->
    RestartStrategy		= one_for_one,
    MaxRestarts			= 1000,
    MaxSecondsBetweenRestarts	= 3600,

    SupFlags			= {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},

    Restart			= permanent,
    Shutdown			= 2000,
    Type			= worker,

    SPChild			= {'splunk_serv', {'splunk_serv', start_link, []},
				   Restart, Shutdown, Type, ['splunk_serv']},
    WSLChild			= {'webmachine_splunk_logger', {'webmachine_splunk_logger', start_link, ["A"]},
				   Restart, Shutdown, Type, ['webmachine_splunk_logger']},
%WSLChild]
    {ok, {SupFlags, [SPChild, WSLChild]}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

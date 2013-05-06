%% @author Justin Sheehy <justin@basho.com>
%% @author Andy Gross <andy@basho.com>
%% @copyright 2007-2008 Basho Technologies
%%
%%    Licensed under the Apache License, Version 2.0 (the "License");
%%    you may not use this file except in compliance with the License.
%%    You may obtain a copy of the License at
%%
%%        http://www.apache.org/licenses/LICENSE-2.0
%%
%%    Unless required by applicable law or agreed to in writing, software
%%    distributed under the License is distributed on an "AS IS" BASIS,
%%    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%    See the License for the specific language governing permissions and
%%    limitations under the License.

-module(webmachine_splunk_logger).
-author('Justin Sheehy <justin@basho.com>').
-author('Andy Gross <andy@basho.com>').
-behaviour(gen_server).
-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).
-export([log_access/1, refresh/0]).
-include_lib("webmachine/include/webmachine_logger.hrl").
-record(state, {}).


start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).
start_link(BaseDir) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [BaseDir], []).

init(_) ->
    defer_refresh(),

    {ok, #state{}}.

refresh() ->
    refresh(now()).

refresh(Time) ->
    gen_server:cast(?MODULE, {refresh, Time}).

log_access(#wm_log_data{}=D) ->
    gen_server:cast(?MODULE, {log_access, D}).

handle_call(_Msg,_From,State) -> {noreply,State}.

handle_cast({log_access, LogData}, State) ->
  
    Msg = format_req(LogData),
    log_write( Msg),
    {noreply, State}.


handle_info({_Label, {From, MRef}, get_modules}, State) ->
    From ! {MRef, [?MODULE]},
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

log_write( IoData) ->
    splunk:access_common(lists:flatten(IoData)).

    


format_req(#wm_log_data{method=Method, 
                        headers=Headers, 
                        peer=Peer, 
                        path=Path,
                        version=Version,
                        response_code=ResponseCode,
                        response_length=ResponseLength}) ->
    User = "-",
    Time = fmtnow(),
    Status = integer_to_list(ResponseCode),
    Length = integer_to_list(ResponseLength),
    Referer = 
        case mochiweb_headers:get_value("Referer", Headers) of
            undefined -> "";
            R -> R
        end,
    UserAgent = 
        case mochiweb_headers:get_value("User-Agent", Headers) of
            undefined -> "";
            U -> U
        end,
    fmt_alog(Time, Peer, User, fmt_method(Method), Path, Version,
             Status, Length, Referer, UserAgent).

fmt_method(M) when is_atom(M) -> atom_to_list(M).


%% Seek backwards to the last valid log entry

defer_refresh() ->
    {_, {_, M, S}} = calendar:universal_time(),
    Time = 1000 * (3600 - ((M * 60) + S)),
    timer:apply_after(Time, ?MODULE, refresh, []).


zeropad_str(NumStr, Zeros) when Zeros > 0 ->
    zeropad_str([$0 | NumStr], Zeros - 1);
zeropad_str(NumStr, _) ->
    NumStr.

zeropad(Num, MinLength) ->
    NumStr = integer_to_list(Num),
    zeropad_str(NumStr, MinLength - length(NumStr)).

suffix({Y, M, D, H}) ->
    YS = zeropad(Y, 4),
    MS = zeropad(M, 2),
    DS = zeropad(D, 2),
    HS = zeropad(H, 2),
    lists:flatten([$., YS, $_, MS, $_, DS, $_, HS]).

fmt_alog(Time, Ip, User, Method, Path, {VM,Vm},
         Status,  Length, Referrer, UserAgent) ->
    [fmt_ip(Ip), " - ", User, [$\s], Time, [$\s, $"], Method, " ", Path,
     " HTTP/", integer_to_list(VM), ".", integer_to_list(Vm), [$",$\s],
     Status, [$\s], Length, [$\s,$"], Referrer,
     [$",$\s,$"], UserAgent, [$",$\n]].

month(1) ->
    "Jan";
month(2) ->
    "Feb";
month(3) ->
    "Mar";
month(4) ->
    "Apr";
month(5) ->
    "May";
month(6) ->
    "Jun";
month(7) ->
    "Jul";
month(8) ->
    "Aug";
month(9) ->
    "Sep";
month(10) ->
    "Oct";
month(11) ->
    "Nov";
month(12) ->
    "Dec".
zone() ->
    Time = erlang:universaltime(),
    LocalTime = calendar:universal_time_to_local_time(Time),
    DiffSecs = calendar:datetime_to_gregorian_seconds(LocalTime) - calendar:datetime_to_gregorian_seconds(Time),
    zone((DiffSecs/3600)*100).

%% Ugly reformatting code to get times like +0000 and -1300

zone(Val) when Val < 0 ->
    io_lib:format("-~4..0w", [trunc(abs(Val))]);
zone(Val) when Val >= 0 ->
    io_lib:format("+~4..0w", [trunc(abs(Val))]).

fmt_ip(IP) when is_tuple(IP) ->
    inet_parse:ntoa(IP);
fmt_ip(undefined) ->
    "0.0.0.0";
fmt_ip(HostName) ->
    HostName.

fmtnow() ->
    {{Year, Month, Date}, {Hour, Min, Sec}} = calendar:local_time(),
    io_lib:format("[~2..0w/~s/~4..0w:~2..0w:~2..0w:~2..0w ~s]",
                  [Date,month(Month),Year, Hour, Min, Sec, zone()]).

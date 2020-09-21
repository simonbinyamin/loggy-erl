-module(logger).
-export([start/1, stop/1]).

start(Nodes) ->
    spawn_link(fun() ->init(Nodes) end).

stop(Logger) ->
    Logger ! stop.

init(Nodes) ->
    Counters = lists:foldl(fun(Node, List) -> [{Node, 1}|List] end, [], Nodes),
    loop(Counters, [], 0).

loop(Counters, Msges, MaxLen) ->
    receive
	{log, From, Time, Msg} ->
	    UpdatedMsges = [{log, From, Time, Msg}|Msges],
	    UpdatedNodeCounters = lists:keyreplace(From, 1, Counters, {From, Time}),
	    LowestCounter = lists:foldl(fun({_Node, T}, Acc) -> erlang:min(T, Acc) end, inf, UpdatedNodeCounters),
	    SafeMsges = lists:filter(fun({log, _Node, T, _Msg}) -> T < LowestCounter end, UpdatedMsges),
	    UnsafeMsges = lists:filter(fun({log, _Node, T, _Msg}) -> T >= LowestCounter end, UpdatedMsges),
	    SortedMsges = lists:keysort(3, SafeMsges),
	    lists:foreach(fun(M) -> log(M) end, SortedMsges),
	    loop(UpdatedNodeCounters, UnsafeMsges, erlang:max(erlang:length(UnsafeMsges), MaxLen));
	stop ->
	    ok
    end.

log({log, From, Time, Msg}) ->
    io:format("log: ~w ~w ~p~n", [From, Time, Msg]).
%% OpenClaw TCP port probe (Erlang) -- checks gateway nodes
-module(tcp_probe).
-export([main/0, probe/2]).

probe(Host, Port) ->
    case gen_tcp:connect(Host, Port, [binary, {active, false}], 3000) of
        {ok, Socket} ->
            gen_tcp:close(Socket),
            true;
        {error, _} ->
            false
    end.

main() ->
    Nodes = [{"localhost", 8080}, {"localhost", 8081}],
    lists:foreach(
        fun({Host, Port}) ->
            Status = case probe(Host, Port) of true -> "OK  "; false -> "FAIL" end,
            io:format("~s ~s:~p~n", [Status, Host, Port])
        end, Nodes).

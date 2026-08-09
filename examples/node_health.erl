%% OpenClaw Node Health Check (Erlang) -- via httpc/inets
-module(node_health).
-export([main/1, check/1]).

check(Url) ->
    inets:start(),
    ssl:start(),
    Request = {Url ++ "/health", []},
    case httpc:request(get, Request, [{timeout, 5000}], []) of
        {ok, {{_Version, Status, _Reason}, _Headers, _Body}} ->
            io_lib:format("OK   ~s: ~p", [Url, Status]);
        {error, Reason} ->
            io_lib:format("FAIL ~s: ~p", [Url, Reason])
    end.

main(Args) ->
    Nodes =
        case Args of
            [] -> ["http://localhost:8080", "http://localhost:8081"];
            _ -> Args
        end,
    lists:foreach(fun(Node) -> io:format("~s~n", [check(Node)]) end, Nodes).

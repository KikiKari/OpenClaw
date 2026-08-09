% OpenClaw Cluster Health Summary (Prolog)
:- initialization(main).

status(node1, 200).
status(node2, 200).
status(node3, 503).
status(node4, 200).

report :-
    forall(status(Node, Code),
           format("node ~w -> HTTP ~w~n", [Node, Code])).

availability(Percent) :-
    findall(N, status(N, _), All),
    findall(N, status(N, 200), Ok),
    length(All, Total),
    length(Ok, OkCount),
    Percent is 100 * OkCount // Total.

main :-
    report,
    availability(P),
    format("cluster availability: ~w %~n", [P]).

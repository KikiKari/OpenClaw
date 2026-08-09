/* OpenClaw Cluster Health Summary (ReasonML) */

let statuses = [200, 200, 503, 200];

let ok =
  List.fold_left((acc, s) => s == 200 ? acc + 1 : acc, 0, statuses);

List.iteri(
  (i, s) => Printf.printf("node %d -> HTTP %d\n", i + 1, s),
  statuses,
);

let availability = 100 * ok / List.length(statuses);
Printf.printf("cluster availability: %d %%\n", availability);

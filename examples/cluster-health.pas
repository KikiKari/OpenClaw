program ClusterHealth;
{ OpenClaw Cluster Health Summary (Pascal) }
const
  NodeCount = 4;
var
  status: array[1..NodeCount] of Integer = (200, 200, 503, 200);
  i, ok: Integer;
begin
  ok := 0;
  for i := 1 to NodeCount do
  begin
    if status[i] = 200 then
      Inc(ok);
    WriteLn('node ', i, ' -> HTTP ', status[i]);
  end;
  WriteLn('cluster availability: ', (100 * ok) div NodeCount, ' %');
end.

with Ada.Text_IO; use Ada.Text_IO;

--  OpenClaw Cluster Health Summary (Ada)
procedure Cluster_Health is
   type Status_Array is array (Positive range <>) of Integer;
   Status : constant Status_Array := (200, 200, 503, 200);
   Ok     : Natural := 0;
begin
   for I in Status'Range loop
      if Status (I) = 200 then
         Ok := Ok + 1;
      end if;
      Put_Line ("node" & Integer'Image (I) & " -> HTTP" & Integer'Image (Status (I)));
   end loop;
   Put_Line ("cluster availability:" & Integer'Image (100 * Ok / Status'Length) & " %");
end Cluster_Health;

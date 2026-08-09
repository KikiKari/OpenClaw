with Ada.Text_IO; use Ada.Text_IO;
with GNAT.Sockets; use GNAT.Sockets;

--  OpenClaw TCP port probe (Ada) — checks gateway nodes
procedure Tcp_Probe is

   function Probe (Host : String; Port : Port_Type) return Boolean is
      Sock : Socket_Type;
      Addr : Sock_Addr_Type;
   begin
      Addr.Addr := Addresses (Get_Host_By_Name (Host), 1);
      Addr.Port := Port;
      Create_Socket (Sock);
      Connect_Socket (Sock, Addr);
      Close_Socket (Sock);
      return True;
   exception
      when others =>
         return False;
   end Probe;

   procedure Check (Host : String; Port : Port_Type) is
      Status : constant String := (if Probe (Host, Port) then "OK  " else "FAIL");
   begin
      Put_Line (Status & " " & Host & ":" & Port_Type'Image (Port));
   end Check;

begin
   Initialize;
   Check ("localhost", 8080);
   Check ("localhost", 8081);
   Finalize;
end Tcp_Probe;

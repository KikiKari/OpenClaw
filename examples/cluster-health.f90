! OpenClaw Cluster Health Summary (Fortran)
program cluster_health
  implicit none
  integer, dimension(4) :: status = [200, 200, 503, 200]
  integer :: i, ok
  real :: availability

  ok = 0
  do i = 1, size(status)
    if (status(i) == 200) ok = ok + 1
    print '(A,I0,A,I0)', "node ", i, " -> HTTP ", status(i)
  end do

  availability = 100.0 * real(ok) / real(size(status))
  print '(A,F5.1,A)', "cluster availability: ", availability, " %"
end program cluster_health

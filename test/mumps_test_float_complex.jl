icntl = default_icntl[:]
icntl[1] = 0
icntl[2] = 0
icntl[3] = 0
icntl[4] = 0
tol = sqrt(eps(Float32))

mumps1 = Mumps{ComplexF32}(mumps_definite, icntl, default_cntl32)
A = sparse(Diagonal([1.0, 2.0, 3.0, 4.0]))
factorize!(mumps1, A);  # Analyze and factorize.
rhs = [1.0, 4.0, 9.0, 16.0]
x = solve(mumps1, rhs)
finalize(mumps1)
MPI.Barrier(comm)
@test(norm(A * x - rhs) <= tol * norm(rhs) * norm(A, 1))

mumps1_unsafe = Mumps{ComplexF32}(mumps_definite, icntl, default_cntl32);
A = sparse(Diagonal(Array{ComplexF32}([1.0, 2.0, 3.0, 4.0])))
associate_matrix!(mumps1_unsafe, A; unsafe = true)
factorize!(mumps1_unsafe);  # Analyze and factorize.
rhs = Array{ComplexF32}([1.0, 4.0, 9.0, 16.0])
orig_rhs = copy(rhs)
associate_rhs!(mumps1_unsafe, rhs; unsafe = true)
solve!(mumps1_unsafe)
x = similar(orig_rhs)
get_sol!(x, mumps1_unsafe)
finalize(mumps1_unsafe)
MPI.Barrier(comm)
@test(norm(A * x - orig_rhs) <= tol * norm(orig_rhs) * norm(A, 1))

mumps2 = Mumps{ComplexF32}(mumps_unsymmetric, icntl, default_cntl32)
A = random_matrix(Float64, [1, 2, 3, 4], 4, 4);
A = sparse(A + A');
factorize!(mumps2, A)
rhs = [1.0, 4.0, 9.0, 16.0]
x = solve(mumps2, rhs)
finalize(mumps2)
MPI.Barrier(comm)
@test(norm(A * x - rhs) <= tol * norm(rhs) * norm(A, 1))

mumps3 = Mumps{ComplexF32}(mumps_unsymmetric, icntl, default_cntl32)
A = sparse(random_matrix(ComplexF32, [1, 2, 3, 4], 4, 4));
factorize!(mumps3, A)
rhs = map(ComplexF32, [1.0, 4.0, 9.0, 16.0] + im * [1.0, 4.0, 9.0, 16.0])
x = solve(mumps3, rhs)
finalize(mumps3)
MPI.Barrier(comm)
@test(norm(A * x - rhs) <= tol * norm(rhs) * norm(A, 1))

mumps3_unsafe = Mumps{ComplexF32}(mumps_unsymmetric, icntl, default_cntl32);
A = sparse(random_matrix(ComplexF32, [1, 2, 3, 4], 4, 4))
associate_matrix!(mumps3_unsafe, A; unsafe = true)
factorize!(mumps3_unsafe);  # Analyze and factorize.
rhs = Array{ComplexF32}([1.0, 4.0, 9.0, 16.0])
orig_rhs = copy(rhs)
associate_rhs!(mumps3_unsafe, rhs; unsafe = true)
solve!(mumps3_unsafe)
x = similar(orig_rhs)
get_sol!(x, mumps3_unsafe)
finalize(mumps3_unsafe)
MPI.Barrier(comm)
@test(norm(A * x - orig_rhs) <= tol * norm(orig_rhs) * norm(A, 1))

# Test convenience interface.

n = 10;
n3 = n * n * n
A = convert(SparseMatrixCSC{ComplexF32, Int32}, map(ComplexF32, get_div_grad(n, n, n)))

# Test with single rhs
if MPI.Comm_rank(comm) == root
  println("Test single rhs on div_grad matrix")
end
rhs = map(ComplexF32, ones(n3) + im * ones(n3))

x = solve(A, rhs, sym = mumps_unsymmetric)
MPI.Barrier(comm)
relres = norm(A * x - rhs) / norm(rhs) / norm(A, 1)
@test(relres <= tol)

# Test with multiple rhs
if MPI.Comm_rank(comm) == root
  println("Test multiple rhs on div_grad matrix")
end
nrhs = 5
rhs =
  map(ComplexF32, ones(n3, nrhs) + im * ones(n3, nrhs)) *
  diagm(0 => Array{Float32}(collect(1:nrhs)))

x = solve(A, rhs, sym = mumps_unsymmetric)

MPI.Barrier(comm)
relres = zeros(Float32, nrhs)
for i = 1:nrhs
  relres[i] = norm(A * x[:, i] - rhs[:, i]) / norm(rhs[:, i]) / norm(A, 1)
  @test(relres[i] <= tol)
end

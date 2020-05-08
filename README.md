# clusterTest

Test the performance of a cluster using weak scaling, i. e. increase the number of cells to scale linearly with the number of CPU cores. The number of cells should be about 100,000 cells per CPU cores.

To setup the test, the following three files have to be modified in the case folder:

    params                  # change factor to the number of cores
    system/decomposeParDict # change numberOfSubdomains to the number of cores
    Allrun                  # change the number of processes (after mpirun -n) to the number of cores
     
See also the results of [CFD Direct](https://cfd.direct/cloud/openfoam-hpc-aws-c5n/#weir-flow)

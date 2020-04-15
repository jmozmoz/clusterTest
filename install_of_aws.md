# Install OpenFOAM on AWS

This tutorial shows all steps needed to install and configure OpenFOAM to work on Amazon EC2 instances using Elastic Fabric Adapter (EFA) network devices. The installation is based on `Ubuntu Server 18.04 LTS (HVM) Amazon Machine Image (AMI)`, the special version of OpenMPI which support the EFA network devices and the [package of OpenFOAM](https://openfoam.org/download/7-ubuntu/) provided the OpenFOAM Foundation.

**This tutorial is provided without any warranty. Costs will accrue by using the different services of AWS! Make sure to always _terminate_ instances, if they are not needed.**

The installation instructions are based on the guide given by [Amazon](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html), [cfd.direct](https://cfd.direct/cloud/aws/cluster/) and [the OpenFOAM Foundation](https://openfoam.org/download/7-ubuntu/).

The following steps use the EC2 consdole and not the command line tools.

The installation includes only the software/steps necessary to create a minimal setup. It does not use dedicated AMIs like the one provided by the [OpenFOAM Foundation](https://aws.amazon.com/marketplace/pp/B017AHYO16/), nor does it use the [AWS ParallelCluster management tool](https://aws.amazon.com/blogs/opensource/aws-parallelcluster/).

During the installation, it is assumed that the instance type **c5n.18xlarge** is used. The installation can be performed on any (64-bit x86) instance type, but most of them do not provide an EFA network devices, so the setup cannot be tested immediately.


## EFA network devices
To achieve high performance of HPC applications like CFD, the communication between different "nodes" of a cluster should be as fast as possible, i.e. high throughput and low latency. Normally, special network hardware is used for this, e. g. [InfiniBand](https://en.wikipedia.org/wiki/InfiniBand). On AWS a special kind of ethernet connection is available for certain kinds of instances which improves the network performance between the instances. It is called 
["Elastic Fabric Adapter" (EFA)](https://aws.amazon.com/hpc/efa/).

To use EFA different the following settings have to be chosen and preparations have to be made.

## Create a special security groups
(for a more detailed user guide can be found [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa-start.html))

By default, instances on AWS cannot communicate with each other or with the internet. Therefore, it is necessary to create so called security groups to allow in- and outbound communication. At least the master node of the virtual cluster needs to be reachable by SSH from at least one IP address on the internet. A security group named e.g. **cluster-head** must be created:

In the EC2 console select `NETWORK & SECURITY -> Security Groups -> Create Security Group`. Choose a Security group name and description and press `Create`. Do not add/modify any rules in the creation step. Then select the newly created group, then `Inbound->Edit`. In the `Type` drop-down menu, select `SSH`, for `Source` either `Anywhere` or `My IP`. If your IP addresses will change in the future then you will also have to edit the security group accordingly in the future. Select `Save`. No changes are necessary for the `Outbound` rule (allow traffic to all IP addresses).

For the cluster nodes to be able to communicate with each other, an additional Security Group is necessary. Create an additional group as described above (name it e. g. **cluster**). Again, do not add/modify any rules in the creation step. Select this new group., then `Inbound->Edit`. For `Type` select `All traffic`. In the Source drop-down menu, select `Custom`. Then select the box for `CIDR, IP or Security Group`. In this box start typing the name of this security groups, e. g. **cluster**. A drop-down menu will appear showing all groups matching the input. Select the name of this security group. The internal name (something like **sg-0123456789abcef**) will appear. Then select `Outbound->Edit`. There, input the same rule as for `Inbound`. **It is necessary to change the existing rule (All traffic to all destinations), because it will not work!** (see also [this forum message](https://forums.aws.amazon.com/message.jspa?messageID=923526#923526)). 

## Create AMI containing all necessary software 

In this step a Amazon Machine Image (AMI) will be created which contains the OpenFOAM installation and other software necessary to run the virtual cluster. It is assumed that you have already created [a SSH key pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) and use it.

In the EC2 console start a new instance. Then on the seven tabs apply the following settings:
1. Select `Ubuntu Server 18.04 LTS (HVM), SSD Volume Type` as AMI.
2. To be able to immediately test the Elastic Fabric Adapter (EFA) network devices, choose `c5n.18xlarge` as instance type (or one of the others mention in https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa-start.html#efa-start-tempinstance).
3. Unfortunately, it is currently not possible to choose a `spot instance` and use EFA, if starting form the EC2 console (see [this forum thread](https://forums.aws.amazon.com/message.jspa?messageID=929034#929034)). Choose one of the possible selections under `Subnet` (do not use `No preferences`). Under `Placement Group->Add to a new placement group` and give it a name, e. g. **cluster**. In future starts of instances, always use `Add to existing placement group` and select the name of the group just created. Enable `Elastic Fabric Adapter`. To turn off hyperthreading which actually slows down OpenFOAM, select `CPU options` and set `Threads per core` to 1. 
4. Add storage: Use the shown default settings. 
5. Add tags: No input is needed.
6. Under “Assign a security group” choose `Select an existing security group`, then select both security groups, which have been created above, e. g. **cluster-head** and **cluster**
7. Review your settings and start the instance.

Connect to the newly created instance with the command shown in the console, e. g.

    ssh -i "key.pem" ubuntu@ec2-AAA-BBB-CCC-DDD.us-east-2.compute.amazonaws.com

Follow the steps at to install the correct OpenMPI version: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa-start.html#efa-start-enable (steps 3 and 4)

Then install OpenFOAM (see also [here](https://openfoam.org/download/7-ubuntu/))

    sudo sh -c "wget -O - http://dl.openfoam.org/gpg.key | apt-key add -"
    sudo add-apt-repository http://dl.openfoam.org/ubuntu
    sudo apt-get update
    sudo apt-get -y install openfoam7

For OpenFOAM to work with the AMAZON OpenMPI installation, the MPI wrapper of OpenFOAM has to be recompiled:
  
    sudo su – root
    source /opt/openfoam7/etc/bashrc
    cd /opt/openfoam7/src/Pstream
    ./Allwclean
    ./Allwmake -j
    exit

(The linker command should include the path to the AMAZON mpi library: 
`-L/opt/amazon/openmpi/lib`)

Modify `$HOME/.bashrc`, so MPI processes set up the environment correctly for the special OpenMPI version and OpenFOAM. This has to be added at the **top** of `.bashrc.`

    export=/opt/amazon/openmpi/bin:$PATH
    source /opt/openfoam7/etc/bashrc

For the exchange of data in the virtual cluster, install network file system (NFS). Then, e. g. the OpenFOAM case data are stored only on the cluster and used by all clients.

    sudo apt-get -y install nfs-kernel-server nfs-common
    mkdir -p $HOME/OpenFOAM
    sudo sh -c "echo '/home/ubuntu/OpenFOAM  *(rw,sync,no_subtree_check)' >> /etc/exports"
    sudo exportfs -ra

To allow to automatically connect between the cluster nodes by ssh, create the file `$HOME/.ssh/config` and add the following content:

    Host *
     StrictHostKeyChecking no

After the startup of the cluster, the NFS client must be started on all clients. Also, a file for MPI must be created, which contains the information how to distribute an OpenFOAM run between the instances of the cluster. The script [`setupCluster.sh`](https://github.com/jmozmoz/clusterTest/blob/master/setupCluster.sh) can be used to do this. Copy it to the `$HOME` directory. It is used to setup the cluster (ssh connections, nfs server and clients, hostfile) for the cluster.

     curl -O https://raw.githubusercontent.com/jmozmoz/clusterTest/master/setupCluster.sh
     chmod 755 setupCluster.sh

Create a new AMI following step 7 at https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa-start.html#efa-start-enable

There are at least two ways to enable passwordless SSH connections between the instances of the cluster, needed to run OpenFOAM there. Either follow the instructions in [step 10 of the AWS user guide](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa-start.html#efa-start-enable) to create a special SSH-key pair, or use SSH agent forwarding as described in [steps 3 and 6 of the cfd.direct tutorial](https://cfd.direct/cloud/aws/cluster/).

## Using the cluster

To test the setup for a cluster start at least two instances using the newly created AMI. The first instance is the cluster head with the two security groups **cluster-head** and **cluster**. The other are slaves and only need the security group **cluster**. They can be started as described above.

### Log into the cluster 

You probably would want to create an additional `Elastic Block Storage` (EBS) volumes to store the OpenFOAM cases. For simplicity, this step is left out here and the case is stored on the volume used for the AMI created above.

To allow password less connections between the cluster instances, one way is to use the SSH agent. To use it, the following steps are needed.

On the local computer (not in the AWS cloud), the ssh-agent client must be started and the key for the connection then added:

    eval $(ssh-agent)
    cat key.pem | ssh-add -k -

Then use ssh to connect to the cluster head (add the option -A to the command shown in the EC2 console):

    ssh -A ubuntu@ec2-AAA-BBB-CCC-DDD.us-east-2.compute.amazonaws.com

After logging into the cluster head create a file named `allIPs` in the `$HOME` directory containing all private IP addresses of the cluster nodes, one per line. These IP addresses can be found in the EC2 console on the instances page. It might be necessary to configure it to show the corresponding column. 

Then start the script:

    $HOME/setupCluster.sh
    ubuntu@ip-172-31-15-63:~$ ./setupCluster.sh
    start nfs server
      % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                     Dload  Upload   Total   Spent    Left  Speed
    100    12  100    12    0     0  12000      0 --:--:-- --:--:-- --:--:-- 12000
    myIP:    >172.31.15.63<
    otherIP: >172.31.15.63<
    do not connect to myself: 172.31.15.63 172.31.15.63
    myIP:    >172.31.15.63<
    otherIP: >172.31.1.20<
    connect >172.31.1.20< nfs to >172.31.15.63<
    Warning: Permanently added '172.31.1.20' (ECDSA) to the list of known hosts.


### Test cluster with benchmark case

Download/clone the git repository at https://github.com/jmozmoz/clusterTest.git and adjust the case to run e. g. on two nodes:

     mkdir -p $FOAM_RUN
     run
     git clone https://github.com/jmozmoz/clusterTest.git
     cd clusterTest
     cp -a pitzDaily_3d_01/ pitzDaily_3d_72
     cd pitzDaily_3d_72
     vim params # change factor to 72
     vim system/decomposeParDict # change numberOfSubdomains to 72
     vim Allrun # change the number of processes (after -n) to 72 for mpirun

The run the case:

     ./Allpre
     Running blockMesh on /home/ubuntu/OpenFOAM/ubuntu-7/run/clusterTest/pitzDaily_3d_72
     Running extrudeMesh on /home/ubuntu/OpenFOAM/ubuntu-7/run/clusterTest/pitzDaily_3d_72
     Running decomposePar on /home/ubuntu/OpenFOAM/ubuntu-7/run/clusterTest/pitzDaily_3d_72
     
     ./Allrun
    tail -n 15 log.simpleFoam

    Time = 200

    smoothSolver:  Solving for Ux, Initial residual = 0.00174597, Final residual = 7.84856e-11, No Iterations 10
    smoothSolver:  Solving for Uy, Initial residual = 0.00398625, Final residual = 2.16783e-10, No Iterations 10
    smoothSolver:  Solving for Uz, Initial residual = 0.00869746, Final residual = 3.23425e-10, No Iterations 10
    GAMG:  Solving for p, Initial residual = 0.0126613, Final residual = 0.000391182, No Iterations 10
    time step continuity errors : sum local = 0.00369943, global = -0.00108898, cumulative = -2.57168
    smoothSolver:  Solving for epsilon, Initial residual = 0.00235553, Final residual = 2.54113e-11, No Iterations 10
    smoothSolver:  Solving for k, Initial residual = 0.00324004, Final residual = 6.13386e-11, No Iterations 10
    ExecutionTime = 267.71 s  ClockTime = 267 s

    End

    Finalising parallel run

## Terminating the cluster instances

If terminating the instances, then all changes will applied after their start will be lost, especially the results of the simulation. If they should be stored between sessions, then an EBS additional volume is needed, e. g. mounted to the `/home/ubuntu/OpenFOAM` directory (only) to the master cluster instance.

<a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/">Creative Commons Attribution-ShareAlike 4.0 International License</a>.
#!/bin/bash
#SBATCH --job-name=BATEdry0.0036
#SBATCH --partition=levque
#SBATCH --nodes 1
#SBATCH --mem 23000
#SBATCH --ntasks=8
#SBATCH --cpus-per-task 1
##SBATCH --mem-per-cpu=2400
#SBATCH --output=V30_BAT_E_2035_dry_delta0.0036.out
##SBATCH --error=archivo_%i.err
#SBATCH --mail-user=estebaniglesiasmanriquez@gmail.com
#SBATCH --mail-type=ALL
module load Lmod/6.5
source $LMOD_PROFILE
module load Anaconda3/5.0.1
####module load cplex/12.6.1
$julia V30_BAT_E_2035_dry_delta0.0036.jl


#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sat Aug 18 18:44:29 2018

@author: esteban

"""


import os

#### MIX
year='2035';
base_path='Dropbox/Tesis/Demand Response/UnitCommitment/Scripts/Julia/V30/'
base_file='V30_UC_Analizador.jl'
study='MIX/'
version='V30'
scenariolist=['D','E']
hydrologylist=['humid','dry']


deltalistlist=[['(0.001,0.0036)','0.001_0.0036']]
BetaRlistlist=[['(50,25,100,12.5,150)','12_150']] #betaR toma valores de BAT
BetaClistlist=[['(125,100,150,50,200,300)','50_300']] #betaC toma valores de PJM
theta='1';
factorRE='(1)'
    

home=os.getenv("HOME")+"/"
base_path=home+base_path

f=open(base_path+study+study[:-1]+'.sh',"w")

year='2035'
for delta in deltalistlist:
    for scenario in scenariolist:
        for hydrology in hydrologylist:
            for betaRlist in BetaRlistlist:
                for betaClist in BetaClistlist:
                    with open(base_path+base_file, 'r') as file :
                      filedata = file.read()
                    
                    # Replace the target string
                    filedata = filedata.replace('XXYEARXX', year)
                    filedata = filedata.replace('XXSCENARIOXX', scenario)
                    filedata = filedata.replace('XXHYDROLOGYXX', hydrology)
                    filedata = filedata.replace('XXBETACLISTXX', betaClist[0])
                    filedata = filedata.replace('XXBETARLISTXX', betaRlist[0])
                    filedata = filedata.replace('XXDELTALISTXX', delta[0])
                    filedata = filedata.replace('XXSTUDYXX', study[:-1])
                    filedata = filedata.replace('XXTHETAXX', theta)
                    filedata = filedata.replace('XXFACTORREXX',factorRE)
                    
                    filebase=version+'_'+study[:-1]+'_'+scenario+'_'+year+'_'+hydrology+'_delta'+delta[1][-2:]
                    
                    #Write Julia file                    
                    with open(base_path+study+filebase+'.jl', 'w') as file:
                        file.write(filedata)
                    
                    #Open Slurm                    
                    with open(base_path+'EvaluateSLURM_slims.sh', 'r') as file :
                        fileSLURM = file.read()
                    
                    fileSLURM = fileSLURM.replace('XXFILENAMEXX',filebase)
                    fileSLURM = fileSLURM.replace('XXJNXX', study[:-1]+scenario+hydrology+delta[1][-2:])
                    #Write slurm file                    
                    with open(base_path+study+filebase+'.sh', 'w') as file:
                        file.write(fileSLURM)                     
                    
                        
                    
                    
                    #f.write('$julia '+filename+'\n')
                    f.write('sbatch '+filebase+'.sh\n')
                             
f.close()


 

    
    

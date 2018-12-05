version="V30"
## Importing local variables and data.
study="BAT" #ej: PJM
year="2035";
scenario="E";
hydrology="humid";
beta_c_list=(999999999);
beta_r_list=(50,25,100,12.5,150);
delta_list=(0.0036);
factorRE_list=(1,1.05,1.1);



caller=string(version,"_UC_Caller.jl")
dr_script=string(version,"_UC_DR_Iglesias.jl")
results_saver=string(version,"_UC_ResultsSaver.jl")


this=string(study,"_",scenario,"_",year,"_",hydrology)
version_path=string(version,"/");
study_path=string(version,"_",study,"/");
path_to_data="../../Data/";
path_to_results="../../Results/";
include(string(path_to_data,version_path,"datafiles.jl"));
include("../../LocalVariables/solver.jl");

if Solver=="Gurobi"
	using Gurobi 
end
if Solver=="Cplex"
    using CPLEX
end
using CSV
using DataFrames
using JuMP
import Base.Dates


#using Dates

include(string("../",caller));
include(string("../",dr_script));
include(string("../",results_saver));




T=672;
theta=1;
for factorRE in factorRE_list
	for delta in delta_list
		for beta_r in beta_r_list
			for beta_c in beta_c_list
				specific_name=string(version,	"_",scenario,"_",year,"_",hydrology,"_d",delta,"_bc",beta_c,"_br",beta_r,"_fRE",factorRE)
				file_flag=string(pwd(),"/flags/",specific_name,".jl")
				YAHECHO=0;
				try include(file_flag)
					println(string(specific_name," - ya calculado"))
				catch 
					println("No se ha hecho")
					specific_path=string(path_to_results,study_path,specific_name,"/")

					alpha_r=beta_r*delta;
					alpha_c=beta_c*delta;
					fileoutput = open(string(study_path[1:end-1],".out"), "a")
					write(fileoutput,
						string(Dates.now()),
						study,"-",scenario,"-",year,"-",hydrology,
						",d=",string(delta),
						",bc=",string(beta_c),
						",br=",string(beta_r),
						",fRE=",string(factorRE),
						" - starting... \n")
					close(fileoutput)
					tic()
					(centrales_filename,demand_filename,avail_filename)=DataFiles(year,scenario,hydrology)
					
					try mkdir(string(path_to_results,study_path))
						println("Creating path", string(path_to_results,study_path))
					catch 
						println("Using an existant path" ,string(path_to_results,study_path))
					end

					try mkdir(specific_path)
						println("Creating path", specific_path)
					catch 
						println("Using an existant path" ,specific_path)
					end
					DR_Data=DataFrame(theta=theta,alpha_c=alpha_c,alpha_r=alpha_r,beta_c=beta_c,beta_r=beta_r,delta=delta);
					#(P,C,A,u,ON,OFF,Rdown,Rup,spotP,DataResults)=UC_Caller(DR_Data,T,path_to_data,Solver)
					println("Going to Call")
					#string(path_to_data,version_path) es el path a los resultados
					(P,C,u,ON,OFF,Rdown,Rup,spotP,DataResults,Rc)=UC_Caller(DR_Data,T,string(path_to_data,version_path),demand_filename,avail_filename,centrales_filename,Solver,factorRE)
					#println("We have the resutls")
					#UC_ResultsSaver(P,C,A,u,ON,OFF,Rdown,Rup,spotP,DataResults,specific_path)
					println("Saving Results")
					UC_ResultsSaver(P,C,u,ON,OFF,Rdown,Rup,spotP,DataResults,Rc,specific_path)
					elap=toc()
					elap=round(elap)
					fileoutput = open(string(study_path[1:end-1],"_",this,".txt"), "a")
					write(fileoutput,
						string(Dates.now()),
						study,"-",scenario,"-",year,"-",hydrology,
						",d=",string(delta),
						",bc=",string(beta_c),
						",br=",string(beta_r),
						",fRE=",string(factorRE),
						" - OK .... in ... ",string(elap)," seconds ☺\n")
					close(fileoutput)


					try mkdir(string(pwd(),"/flags/"))
						println("Creating flag path")
					catch 
						println("Using an existant flag path")
					end

					fileflag = open(string(file_flag), "a")

					write(fileflag,"YAHECHO=1\n")
				end
			end
		end
	end
end



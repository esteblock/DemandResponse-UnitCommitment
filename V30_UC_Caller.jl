function UC_Caller(DR_Data,T,path_to_data,demand_filename,avail_filename,centrales_filename,Solver,factorRE)
	Demanda=CSV.read(string(path_to_data,demand_filename));
	Avail=CSV.read(string(path_to_data,avail_filename));
	#Avail_HIDRO=CSV.read(string(path_to_data,avail_HIDRO));
	#Avail=CSV.read(string(path_to_data,avail_filename),delim=';');


	##### Esta todavia creado por excel con puntos y comas
	Centrales=CSV.read(string(path_to_data,centrales_filename));
	println("We have data")
	#println(Solver);
	#println(Centales);
	#println(Demanda);
	tic()
	(P,
		C,
	    u,
	    ON,
	    OFF,
	    ONOFFCost,
	    VarCost,
	    TCost,
	    Rdown,
	    Rup,
	    spotP,
	    Rc,
	    RampCost)=UC_DR_Iglesias(Solver,Centrales,Demanda,Avail,DR_Data,T,factorRE)
	elapsed_time=toc();
	println("We have results")
	DataResults=DataFrame(T = T,
		theta=DR_Data[:theta][1],
		factorRE=factorRE,
		delta=DR_Data[:delta][1],
		beta_c=DR_Data[:beta_c][1],
		beta_r=DR_Data[:beta_r][1],
		total_cost=TCost,
		var_cost=VarCost,
		onoff_cost=ONOFFCost,
		ramp_cost=RampCost,
		elapsed_time=elapsed_time);
	#println("we'll give the results")
	return(P,C,u,ON,OFF,Rdown,Rup,spotP,DataResults,Rc)
end
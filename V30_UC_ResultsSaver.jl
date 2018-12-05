function UC_ResultsSaver(P,C,u,ON,OFF,Rdown,Rup,spotP,DataResults,Rc,path_to_results)
	println("Starting saving results")
	CSV.write(string(path_to_results,"P.csv"),DataFrame(P'));
	CSV.write(string(path_to_results,"C.csv"),DataFrame(C'));
	#CSV.write(string(path_to_results,"A.csv"),DataFrame(A'));
	CSV.write(string(path_to_results,"u.csv"),DataFrame(u'));
	CSV.write(string(path_to_results,"ON.csv"),DataFrame(ON'));
	CSV.write(string(path_to_results,"OFF.csv"),DataFrame(OFF'));
	CSV.write(string(path_to_results,"Rdown.csv"),DataFrame(Rdown'));
	CSV.write(string(path_to_results,"Rup.csv"),DataFrame(Rup'));
	CSV.write(string(path_to_results,"SpotP.csv"),DataFrame(spotP'));
	CSV.write(string(path_to_results,"Rc.csv"),DataFrame(Rc'));
	CSV.write(string(path_to_results,"DataResults.csv"),DataResults);
	println("Results Saved")
end
#At a future date: Make it possible to use multiple Cores on this. Need to make sure the temp objects are being written to different environments but should work automatically.

#Define class of object for the fitted additive model
setClass("oadaAICtable",representation(nbdaMultiDiff
="character",nbdadata="nbdaData",convergence="logical",loglik="numeric",aic="numeric",aicc="numeric",constraintsVectMatrix="matrix", offsetVectMatrix="matrix", MLEs="matrix",SEs="matrix",MLEilv="matrix",SEilv="matrix",MLEint="matrix",SEint="matrix",typeVect="character",deltaAIC="numeric",RelSupport="numeric",AkaikeWeight="numeric",printTable="data.frame"));


#Method for initializing addFit object- including model fitting
setMethod("initialize",
    signature(.Object = "oadaAICtable"),
    function (.Object, nbdadata,typeVect,constraintsVectMatrix,offsetVectMatrix,startValue,method,gradient,iterations,aicUse,lowerList,writeProgressFile,...)
    {


    if(is.null(typeVect)){typeVect<-rep("social",dim(constraintsVectMatrix)[1])}

	 	#If there are multiple diffusions "borrow" the first diffusion to extract necessary parameters
    	if(is.character(nbdadata)){
    	  nbdadataTemp1<-eval(as.name(nbdadata[1]));
    	}else{nbdadataTemp1<-nbdadata}

		#if offset matrix is null set it up to contain zeroes
		if(is.null(offsetVectMatrix)) offsetVectMatrix<-constraintsVectMatrix*0

		noModels<-dim(constraintsVectMatrix)[1]
    #set up progress bar
		pb <- txtProgressBar(min=0, max=noModels, style=3)


		#Calculate the number of different s parameters, ILVs and models to be fitted
		noSParam<-dim(nbdadataTemp1@stMetric)[2]
		noILVasoc<- dim(nbdadataTemp1@asocILVdata)[2] #ILV effects on asocial learning
		noILVint<- dim(nbdadataTemp1@intILVdata)[2] #ILV effects on interation (social learning)
		noILVmulti<- dim(nbdadataTemp1@multiILVdata)[2] #ILV multiplicative model effects
		if(nbdadataTemp1@asoc_ilv[1]=="ILVabsent") noILVasoc<-0
		if(nbdadataTemp1@int_ilv[1]=="ILVabsent") noILVint<-0
		if(nbdadataTemp1@multi_ilv[1]=="ILVabsent") noILVmulti<-0

		#Record asocialVar names
		asocialVarNames<-unique(c(nbdadataTemp1@asoc_ilv,nbdadataTemp1@int_ilv,nbdadataTemp1@multi_ilv))
		asocialVarNames<-asocialVarNames[asocialVarNames!="ILVabsent"]
		if(is.null(asocialVarNames)){noILVs<-0}else{noILVs<-length(asocialVarNames)}

		#Set up matrices to record maximum likelihood estimators and SEs
		MLEs<-matrix(NA,nrow=noModels,ncol=noSParam,dimnames=list(1:noModels, paste("s",1:noSParam,sep="")))
		SEs<-matrix(NA,nrow=noModels,ncol=noSParam,dimnames=list(1:noModels, paste("SEs",1:noSParam,sep="")))
		if(noILVasoc==0){
		  MLEadd<-SEadd<-rep(NA,noModels)
		}else{
		  MLEadd<-matrix(NA,nrow=noModels,ncol= noILVasoc, dimnames=list(1:noModels, nbdadataTemp1@asoc_ilv))
		  SEadd<-matrix(NA,nrow=noModels,ncol= noILVasoc, dimnames=list(1:noModels, nbdadataTemp1@asoc_ilv))
		}
    if(noILVint==0){
      MLEintUC<-SEintUC<-rep(NA,noModels)
    }else{
  		MLEintUC<-matrix(NA,nrow=noModels,ncol= noILVint, dimnames=list(1:noModels, nbdadataTemp1@int_ilv))
  		SEintUC<-matrix(NA,nrow=noModels,ncol= noILVint, dimnames=list(1:noModels,nbdadataTemp1@int_ilv))
    }
		if(noILVmulti==0){
		  MLEmulti<-SEmulti<-rep(NA,noModels)
		}else{
		  MLEmulti<-matrix(NA,nrow=noModels,ncol= noILVmulti, dimnames=list(1:noModels, nbdadataTemp1@multi_ilv))
		  SEmulti<-matrix(NA,nrow=noModels,ncol= noILVmulti, dimnames=list(1:noModels, nbdadataTemp1@multi_ilv))
		}


		#Set up various vectors to record things about each model
		convergence<-loglik<-aic<-aicc<-seApprox<-rep(NA,noModels)

		#Loop through the rows of the constrainstsVectMatrix creating the constrained objects and thus fitting the specified model each time
		for (i in 1:noModels){

		  #Update progress bar
		  setTxtProgressBar(pb, i)
		  #Write file to working directory saying what model we are on
      if(writeProgressFile){write.csv(paste("Currently fitting model",i, "out of", noModels),file=paste("oadaTableProgressFile",nbdadataTemp1@label[1],".txt",sep=""),row.names =F)}


		  constraintsVect<-constraintsVectMatrix[i,]
		  offsetVect <-offsetVectMatrix[i,]

		  #If the user has specified all zeroes for the s parameters, we need to change it to an "asocial" type
		  #And we need to add a one for the first s parameter so the constrained NBDA object can be created
		  #And the ILV numbers need shifting up one, to be shifted down later
		  if(sum(constraintsVect[1:noSParam])==0){
		    typeVect[i]<-"asocial";
		    constraintsVect[1]<-1;
		    constraintsVect[-(1:noSParam)]<-(constraintsVect[-(1:noSParam)]+1)*(constraintsVect[-(1:noSParam)]>0);
		  }

		  if(is.null(startValue)) {
		    newStartValue<-NULL
		  }else{
		    newStartValue<-startValue[constraintsVect!=0]
		  }

		  if(is.null(lowerList)) {
		    lower<-NULL
		  }else{
		    lower<-lowerList[i,]
		    lower<-lower[constraintsVect!=0]
		  }
		  #Create the necessary constrained data objects
		  if(is.character(nbdadata)){
		    nbdadataTemp<-paste(nbdadata,"Temp",sep="")
		    for(dataset in 1:length(nbdadata)){
		      assign(nbdadataTemp[dataset],constrainedNBDAdata(nbdadata=eval(as.name(nbdadata[dataset])),constraintsVect=constraintsVect,offsetVect=offsetVect),envir = .GlobalEnv)
		      }
		  }else{
		    nbdadataTemp<-constrainedNBDAdata(nbdadata=nbdadata,constraintsVect=constraintsVect,offsetVect=offsetVect)
		  }

			#Fit the model
		  model<-NULL
			try(model<-oadaFit(nbdadata= nbdadataTemp,type=typeVect[i],startValue=newStartValue,method=method,gradient=gradient,iterations=iterations))
      if(!is.null(model)){

			#If it is an asocial model, set constraints to 0 for all s parameters and adjust those for ILVs so they start at 1
			if(typeVect[i]=="asocial"){
			  constraintsVect[1:noSParam]<-0;
			  tempCV<-constraintsVect[-(1:noSParam)]
			  if(max(tempCV)>0) constraintsVect[-(1:noSParam)]<-(tempCV-min(tempCV[tempCV>0])+1)*(tempCV>0)
			}

			#Did the model converge?
			if(is.null(unlist(model@optimisation)[1])){
			  convergence[i]<-T
			}else{
			  if(is.na(unlist(model@optimisation)[1])){convergence[i]<-T}else{convergence[i]<-model@optimisation$convergence==0}
			}

			#Record loglik AIC and AICc
			loglik[i]<-model@loglik
			aic[i]<-model@aic
			aicc[i]<-model@aicc

			#Record MLE and SE for s parameters
			for(j in unique(constraintsVect[1:noSParam])){
			  if(j==0){
			    MLEs[i,constraintsVect[1:noSParam]==j]<-0
			    SEs[i,constraintsVect[1:noSParam]==j]<-0
			  }else{
  			  MLEs[i,constraintsVect[1:noSParam]==j]<-model@outputPar[j]
  			  SEs[i,constraintsVect[1:noSParam]==j]<-model@se[j]
			  }
 			}

			#Record MLE and SE for the  effect of additive ILVs on asocial learning
			if(noILVasoc>0){
			for(j in unique(constraintsVect[(noSParam+1):(noSParam+ noILVasoc)])){
			  if(j==0){
			    MLEadd[i,constraintsVect[(noSParam+1):(noSParam+ noILVasoc)]==j]<-0
			    SEadd[i,constraintsVect[(noSParam+1):(noSParam+ noILVasoc)]==j]<-0
			  }else{
			    MLEadd[i,constraintsVect[(noSParam+1):(noSParam+ noILVasoc)]==j]<-model@outputPar[j]
			    SEadd[i,constraintsVect[(noSParam+1):(noSParam+ noILVasoc)]==j]<-model@se[j]
			  }
			}
			}

			#Record MLE and SE for the  effect of interactive ILVs on social learning
      if(noILVint>0){
			for(j in unique(constraintsVect[(noSParam+noILVasoc+1):(noSParam+ noILVasoc+noILVint)])){
			  if(j==0){
			    MLEintUC[i,constraintsVect[(noSParam+noILVasoc+1):(noSParam+ noILVasoc+noILVint)]==j]<-0
			    SEintUC[i,constraintsVect[(noSParam+noILVasoc+1):(noSParam+ noILVasoc+noILVint)]==j]<-0
			  }else{
			    MLEintUC[i,constraintsVect[(noSParam+noILVasoc+1):(noSParam+ noILVasoc+noILVint)]==j]<-model@outputPar[j]
			    SEintUC[i,constraintsVect[(noSParam+noILVasoc+1):(noSParam+ noILVasoc+noILVint)]==j]<-model@se[j]
			  }
			}
      }

			#Record MLE and SE for the  effect of multiplicative ILVs on social and asocial learning
			if(noILVmulti>0){
			for(j in unique(constraintsVect[(noSParam+noILVasoc+noILVint+1):(noSParam+ noILVasoc+noILVint+noILVmulti)])){
			 if(j==0){
			    MLEmulti[i,constraintsVect[(noSParam+noILVasoc+noILVint+1):(noSParam+ noILVasoc+noILVint+noILVmulti)]==j]<-0
			    SEmulti[i,constraintsVect[(noSParam+noILVasoc+noILVint+1):(noSParam+ noILVasoc+noILVint+noILVmulti)]==j]<-0
			  }else{
			    MLEmulti[i,constraintsVect[(noSParam+noILVasoc+noILVint+1):(noSParam+ noILVasoc+noILVint+noILVmulti)]==j]<-model@outputPar[j]
			    SEmulti[i,constraintsVect[(noSParam+noILVasoc+noILVint+1):(noSParam+ noILVasoc+noILVint+noILVmulti)]==j]<-model@se[j]
			  }
			}
		}
      }
		}

		#We can now sum up the effects on asocial and social learning for each variable
		MLEilv<-matrix(0,nrow=noModels,ncol= noILVs, dimnames=list(1:noModels, paste("ASOCIAL",asocialVarNames,sep="")))
		SEilv<-matrix(0,nrow=noModels,ncol= noILVs, dimnames=list(1:noModels, paste("SEasocial",asocialVarNames,sep="")))
		MLEint<-matrix(0,nrow=noModels,ncol= noILVs, dimnames=list(1:noModels, paste("SOCIAL",asocialVarNames,sep="")))
		SEint<-matrix(0,nrow=noModels,ncol= noILVs, dimnames=list(1:noModels, paste("SEsocial",asocialVarNames,sep="")))


		for(variable in 1:length(asocialVarNames)){
		  if(sum(unlist(dimnames(MLEadd)[2])==asocialVarNames[variable])>0){
		    MLEilv[,variable]<-MLEilv[,variable]+MLEadd[,unlist(dimnames(MLEadd)[2])==asocialVarNames[variable]]
		    SEilv[,variable]<-SEilv[,variable]+SEadd[,unlist(dimnames(SEadd)[2])==asocialVarNames[variable]]
		  }
		  if(sum(unlist(dimnames(MLEmulti)[2])==asocialVarNames[variable])>0){
		    MLEilv[,variable]<-MLEilv[,variable]+MLEmulti[,unlist(dimnames(MLEmulti)[2])==asocialVarNames[variable]]
		    SEilv[,variable]<-SEilv[,variable]+SEmulti[,unlist(dimnames(SEmulti)[2])==asocialVarNames[variable]]
	      MLEint[,variable]<-MLEint[,variable]+MLEmulti[,unlist(dimnames(MLEmulti)[2])==asocialVarNames[variable]]*(typeVect!="asocial")
		    SEint[,variable]<-SEint[,variable]+SEmulti[,unlist(dimnames(SEmulti)[2])==asocialVarNames[variable]]*(typeVect!="asocial")

		  }
		  if(sum(unlist(dimnames(MLEintUC)[2])==asocialVarNames[variable])>0){
		    MLEint[,variable]<-MLEint[,variable]+MLEintUC[,unlist(dimnames(MLEintUC)[2])==asocialVarNames[variable]]
		    SEint[,variable]<-SEint[,variable]+SEintUC[,unlist(dimnames(SEintUC)[2])==asocialVarNames[variable]]
		  }
		}

		#calculate deltaAIC based on AICc unless user specifies AIC
		if(aicUse=="aic") {deltaAIC<-aic-min(aic)}else{deltaAIC<-aicc-min(aicc)}
		RelSupport<-exp(-0.5*deltaAIC)
		AkaikeWeight<-RelSupport/sum(RelSupport)

		#Give some dimnames to constraints and offset matrices
		varNames<-c(unlist(dimnames(MLEs)[2]))
		if(noILVasoc>0) varNames<-c(varNames,paste("ASOC:",nbdadataTemp1@asoc_ilv, sep=""))
		if(noILVint>0) varNames<-c(varNames,paste("SOCIAL:",nbdadataTemp1@int_ilv, sep=""))
		if(noILVmulti>0) varNames<-c(varNames,paste("A&S:",nbdadataTemp1@multi_ilv,sep=""))

		dimnames(constraintsVectMatrix)=list(1:noModels,paste("CONS:", varNames    ,sep=""))
		dimnames(offsetVectMatrix)=list(1:noModels,paste("OFF", varNames  ,sep=""))

		#Identify which models are asocial models and assign them that type
		typeVect[apply(cbind(constraintsVectMatrix[,1:noSParam]),1,sum)==0]<-"asocial"

		#Classify model types according to ILV effects fitted
		newType<-rep(NA,length(typeVect))

		if(noILVasoc>0&noILVint>0&noILVmulti>0){
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+1):(noSParam+noILVasoc)]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVint)]),1,sum)==0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+noILVint+1):(noSParam+noILVasoc+noILVint+noILVmulti)]),1,sum)==0]<-"additive"
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+1):(noSParam+noILVasoc)]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVint)]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+noILVint+1):(noSParam+noILVasoc+noILVint+noILVmulti)]),1,sum)==0]<-"unconstrained"
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+1):(noSParam+noILVasoc)]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVint)]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+noILVint+1):(noSParam+noILVasoc+noILVint+noILVmulti)]),1,sum)>0]<-"mixed"
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+1):(noSParam+noILVasoc)]),1,sum)==0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVint)]),1,sum)==0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+noILVint+1):(noSParam+noILVasoc+noILVint+noILVmulti)]),1,sum)>0]<-"multiplicative"
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+1):(noSParam+noILVasoc)]),1,sum)==0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVint)]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+noILVint+1):(noSParam+noILVasoc+noILVint+noILVmulti)]),1,sum)==0]<-"socialEffectsOnly"
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+1):(noSParam+noILVasoc)]),1,sum)==0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVint)]),1,sum)==0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+noILVint+1):(noSParam+noILVasoc+noILVint+noILVmulti)]),1,sum)==0]<-"noILVs"
		}
		if(noILVasoc==0&noILVint>0&noILVmulti>0){
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVint)]),1,sum)==0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+noILVint+1):(noSParam+noILVasoc+noILVint+noILVmulti)]),1,sum)==0]<-"socialEffectsOnly"
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVint)]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+noILVint+1):(noSParam+noILVasoc+noILVint+noILVmulti)]),1,sum)>0]<-"mixed"
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVint)]),1,sum)==0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+noILVint+1):(noSParam+noILVasoc+noILVint+noILVmulti)]),1,sum)>0]<-"multiplicative"
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVint)]),1,sum)==0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+noILVint+1):(noSParam+noILVasoc+noILVint+noILVmulti)]),1,sum)==0]<-"noILVs"
		}
		if(noILVasoc>0&noILVint==0&noILVmulti>0){
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+1):(noSParam+noILVasoc)]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+noILVint+1):(noSParam+noILVasoc+noILVint+noILVmulti)]),1,sum)==0]<-"additive"
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+1):(noSParam+noILVasoc)]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+noILVint+1):(noSParam+noILVasoc+noILVint+noILVmulti)]),1,sum)>0]<-"mixed"
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+1):(noSParam+noILVasoc)]),1,sum)==0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+noILVint+1):(noSParam+noILVasoc+noILVint+noILVmulti)]),1,sum)>0]<-"multiplicative"
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+1):(noSParam+noILVasoc)]),1,sum)==0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+noILVint+1):(noSParam+noILVasoc+noILVint+noILVmulti)]),1,sum)==0]<-"noILVs"
		}
		if(noILVasoc>0&noILVint>0&noILVmulti==0){
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+1):(noSParam+noILVasoc)]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVint)]),1,sum)==0]<-"additive"
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+1):(noSParam+noILVasoc)]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVint)]),1,sum)>0]<-"unconstrained"
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+1):(noSParam+noILVasoc)]),1,sum)==0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVint)]),1,sum)==0]<-"noILVs"
		}
		if(noILVasoc==0&noILVint==0&noILVmulti>0){
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+noILVint+1):(noSParam+noILVasoc+noILVint+noILVmulti)]),1,sum)>0]<-"multiplicative"
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+noILVint+1):(noSParam+noILVasoc+noILVint+noILVmulti)]),1,sum)==0]<-"noILVs"
		}
		if(noILVasoc>0&noILVint==0&noILVmulti==0){
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+1):(noSParam+noILVasoc)]),1,sum)>0]<-"additive"
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+1):(noSParam+noILVasoc)]),1,sum)==0]<-"noILVs"
		}
		if(noILVasoc==0&noILVint>0&noILVmulti==0){
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVint)]),1,sum)>0]<-"socialEffectsOnly"
		  newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)>0&apply(as.matrix(constraintsVectMatrix[,(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVint)]),1,sum)==0]<-"noILVs"
		}
		newType[apply(as.matrix(constraintsVectMatrix[,1:noSParam]),1,sum)==0]<-"asocial"
		newType[typeVect=="asocial"]<-"asocial"

		#Classify model types according to combination of network constraints used
		netCombo<-rep(NA,length(typeVect))
		for(i in 1:length(typeVect)){
		  netCombo[i]<- paste(constraintsVectMatrix[i,1:noSParam],collapse=":")
		}

		if(aicUse=="aic"){
		  printTable<-data.frame(model=1:noModels,type=newType,netCombo=netCombo,constraintsVectMatrix, offsetVectMatrix,convergence,loglik,MLEs,MLEilv,MLEint,MLEadd,MLEintUC,MLEmulti,SEs,SEilv,SEint,SEadd,SEintUC,SEmulti,aic,aicc,deltaAIC,RelSupport,AkaikeWeight)
		  printTable <-printTable[order(aic),]
		}else{
		  printTable<-data.frame(model=1:noModels,type=newType,netCombo=netCombo,constraintsVectMatrix, offsetVectMatrix,convergence,loglik,MLEs,MLEilv,MLEint,MLEadd,MLEintUC,MLEmulti,SEs,SEilv,SEint,SEadd,SEintUC,SEmulti,aic,aicc, deltaAICc=deltaAIC,RelSupport,AkaikeWeight)
		  printTable <-printTable[order(aicc),]
		}

		close(pb)

		if(is.character(nbdadata)){
		  callNextMethod(.Object, nbdaMultiDiff=nbdadata, nbdadata = nbdadataTemp1,convergence= convergence, loglik= loglik,aic= aic,aicc= aicc,constraintsVectMatrix= constraintsVectMatrix, offsetVectMatrix= offsetVectMatrix, MLEs= MLEs,SEs= SEs,MLEilv= MLEilv,SEilv= SEilv,MLEint= MLEint,SEint= SEint,typeVect= newType,deltaAIC= deltaAIC,RelSupport= RelSupport,AkaikeWeight= AkaikeWeight,printTable=printTable)
		}else{
		  callNextMethod(.Object, nbdaMultiDiff="NA", nbdadata = nbdadata, convergence= convergence, loglik= loglik,aic= aic,aicc= aicc,constraintsVectMatrix= constraintsVectMatrix, offsetVectMatrix= offsetVectMatrix, MLEs= MLEs,SEs= SEs,MLEilv= MLEilv,SEilv= SEilv,MLEint= MLEint,SEint= SEint,typeVect= newType,deltaAIC= deltaAIC,RelSupport= RelSupport,AkaikeWeight= AkaikeWeight,printTable=printTable)

		}
    }
)



#Function for implementing the initialization
oadaAICtable <-function(nbdadata,  constraintsVectMatrix,typeVect=NULL, offsetVectMatrix = NULL, startValue=NULL,method="nlminb", gradient=T,iterations=150,aicUse="aicc",lowerList=NULL,writeProgressFile=F){
	return(new("oadaAICtable",nbdadata= nbdadata, typeVect= typeVect, constraintsVectMatrix= constraintsVectMatrix, offsetVectMatrix = offsetVectMatrix, startValue= startValue,method= method, gradient= gradient,iterations= iterations,aicUse= aicUse,lowerList=lowerList,writeProgressFile=writeProgressFile))

}

#Method for initializing addFit object- including model fitting
print.oadaAICtable<-function (oadaAICtable)
    {
		oadaAICtable@printTable
	}

typeSupport<-function(oadaAICtable){
	#Calculate support for each type of model in the table
	support<-tapply(oadaAICtable@printTable$AkaikeWeight, oadaAICtable@printTable$type,sum)
	numbers<-tapply(oadaAICtable@printTable$AkaikeWeight, oadaAICtable@printTable$type,length)
	return(data.frame(support=support,numberOfModels=numbers))
}

networksSupport<-function(oadaAICtable){
  #Calculate support for each combination of network constraints in the table
  support<-tapply(oadaAICtable@printTable$AkaikeWeight, oadaAICtable@printTable$netCombo,sum)
  numbers<-tapply(oadaAICtable@printTable$AkaikeWeight, oadaAICtable@printTable$netCombo,length)
  return(data.frame(support=support,numberOfModels=numbers))
}

typeByNetworksSupport<-function(oadaAICtable){
  typesList<-levels(oadaAICtable@printTable$type)
  netComboList<-levels(oadaAICtable@printTable$netCombo)
  output<-array(NA,dim=c(length(netComboList),nrow=length(typesList),2))
  for(i in 1:length(typesList)){
    output[,i,1]<-tapply(oadaAICtable@printTable$AkaikeWeight[oadaAICtable@printTable$type==typesList[i]], oadaAICtable@printTable$netCombo[oadaAICtable@printTable$type==typesList[i]],sum)
    output[,i,2]<-tapply(oadaAICtable@printTable$AkaikeWeight[oadaAICtable@printTable$type==typesList[i]], oadaAICtable@printTable$netCombo[oadaAICtable@printTable$type==typesList[i]],length)
  }
  output[is.na(output[,,2])]<-0
  dimnames(output)<-list(netComboList,typesList,c("Support","NumberOfModels"))
  return(output)
}



variableSupport<-function(oadaAICtable,typeFilter=NULL,includeAsocial=TRUE){
	#Extract the printTable and correct type to include asocial labels
	printTable<-oadaAICtable@printTable

	#Extract number of s parameters
	noSParam<-dim(oadaAICtable@MLEs)[2]
	#Extract number of ILVs
	noILVs <-dim(oadaAICtable@MLEilv)[2]


	#Filter as requested by the user
	if(!is.null(typeFilter)) {
		if(includeAsocial){
			printTable<-printTable[printTable$type==typeFilter|printTable$type=="asocial",]
		}else{
			printTable<-printTable[printTable$type==typeFilter,]
		}
	}
	#Correct Akaike Weights for the new subset of models
	printTable$AkaikeWeight<-printTable$AkaikeWeight/sum(printTable$AkaikeWeight)

	#Set up a vector to record the support for each variable
	support<-rep(NA,dim(oadaAICtable@constraintsVectMatrix)[2])
	for(i in 1:dim(oadaAICtable@constraintsVectMatrix)[2]){
		support[i]<-sum(printTable$AkaikeWeight[printTable[,(i+3)]!=0])
	}
	#Convert support into a matrix so I can add dimnames
	support<-rbind(support)
	#Give the support vector some dimension names
	tempNames<-unlist(dimnames(oadaAICtable@constraintsVectMatrix)[2])
	dimnames(support)[2]=list(gsub("CONS:","",tempNames))

	return(support)

}


modelAverageEstimates<-function(oadaAICtable,typeFilter=NULL,netFilter=NULL,includeAsocial=TRUE,averageType="mean"){
	#Extract the printTable and correct type to include asocial labels
	printTable<-oadaAICtable@printTable

	#Extract number of s parameters
	noSParam<-dim(oadaAICtable@MLEs)[2]
	#Extract number of ILVs
	noILVs <-dim(oadaAICtable@MLEilv)[2]

	AkaikeWeight <-oadaAICtable@AkaikeWeight[order(-oadaAICtable@AkaikeWeight)]
	MLEs<-as.matrix(oadaAICtable@MLEs[order(-oadaAICtable@AkaikeWeight),])
	MLEilv<-as.matrix(oadaAICtable@MLEilv[order(-oadaAICtable@AkaikeWeight),])
	MLEint<-as.matrix(oadaAICtable@MLEint[order(-oadaAICtable@AkaikeWeight),])


	#Filter as requested by the user
	if(!is.null(typeFilter)) {
		if(includeAsocial){
			MLEs <-MLEs[printTable$type==typeFilter|printTable$type=="noILVs"|printTable$type=="asocial",]
			MLEilv <-MLEilv[printTable$type==typeFilter|printTable$type=="noILVs"|printTable$type=="asocial",]
			MLEint <-MLEint[printTable$type==typeFilter|printTable$type=="noILVs"|printTable$type=="asocial",]
			AkaikeWeight<-AkaikeWeight[printTable$type==typeFilter|printTable$type=="noILVs"|printTable$type=="asocial"]
			netCombo<-printTable$netCombo[printTable$type==typeFilter|printTable$type=="noILVs"|printTable$type=="asocial"]
		}else{
			MLEs <-MLEs[printTable$type==typeFilter|printTable$type=="noILVs",]
			MLEilv <-MLEilv[printTable$type==typeFilter|printTable$type=="noILVs",]
			MLEint <-MLEint[printTable$type==typeFilter|printTable$type=="noILVs",]
			AkaikeWeight<-AkaikeWeight[printTable$type==typeFilter|printTable$type=="noILVs"]
			netCombo<-printTable$netCombo[printTable$type==typeFilter|printTable$type=="noILVs"]
		}
	}else{netCombo<-printTable$netCombo}
	#Filter by network as requested by the user
	if(!is.null(netFilter)) {
	    MLEs <-MLEs[netCombo==netFilter,]
	    MLEilv <-MLEilv[netCombo==netFilter,]
	    MLEint <-MLEint[netCombo==netFilter,]
	    AkaikeWeight<-AkaikeWeight[netCombo==netFilter]
	 }

	#Correct Akaike Weights for the new subset of models
	AkaikeWeight<-AkaikeWeight/sum(AkaikeWeight)

	#Do means first and then replace with model weighted medians if requested
	MAvs<-apply(as.matrix(MLEs*AkaikeWeight),2,sum)
	MAvilv<-apply(as.matrix(MLEilv*AkaikeWeight),2,sum)
	MAvint<-apply(as.matrix(MLEint*AkaikeWeight),2,sum)

  if(averageType=="mean"){

  }else{
  	if(averageType=="median"){
  	  for(i in 1:dim(MLEs)[2]){
  	    tempMLE<-MLEs[,i]
  	    tempMLEordered<-tempMLE[order(tempMLE)]
  	    tempAW<-AkaikeWeight[order(tempMLE)]
  	    cumulAW<-cumsum(tempAW)
  	    MAvs[i]<-tempMLEordered[min(which(cumulAW>0.5))]
  	  }
  	  for(i in 1:dim(MLEilv)[2]){
  	    tempMLE<-MLEilv[,i]
  	    tempMLEordered<-tempMLE[order(tempMLE)]
  	    tempAW<-AkaikeWeight[order(tempMLE)]
  	    cumulAW<-cumsum(tempAW)
  	    MAvilv[i]<-tempMLEordered[min(which(cumulAW>0.5))]
  	  }
  	  for(i in 1:dim(MLEint)[2]){
  	    tempMLE<-MLEint[,i]
  	    tempMLEordered<-tempMLE[order(tempMLE)]
  	    tempAW<-AkaikeWeight[order(tempMLE)]
  	    cumulAW<-cumsum(tempAW)
  	    MAvint[i]<-tempMLEordered[min(which(cumulAW>0.5))]
  	  }

  	}else{
  	  print("Invalid averageType, please select 'mean' or 'median'");
  	  return(NULL)
  	}
  }


	return(c(MAvs, MAvilv, MAvint))
}

#To be modified from model averaged estimates function
unconditionalStdErr<-function(oadaAICtable,typeFilter=NULL,netFilter=NULL,includeAsocial=TRUE,includeNoILVs=TRUE,nanReplace=FALSE){
	#Extract the printTable and correct type to include asocial labels
  #Extract the printTable and correct type to include asocial labels
  printTable<-oadaAICtable@printTable

  #Extract number of s parameters
  noSParam<-dim(oadaAICtable@MLEs)[2]
  #Extract number of ILVs
  noILVs <-dim(oadaAICtable@MLEilv)[2]

  AkaikeWeight <-oadaAICtable@AkaikeWeight[order(-oadaAICtable@AkaikeWeight)]
  MLEs<-as.matrix(oadaAICtable@MLEs[order(-oadaAICtable@AkaikeWeight),])
  MLEilv<-as.matrix(oadaAICtable@MLEilv[order(-oadaAICtable@AkaikeWeight),])
  MLEint<-as.matrix(oadaAICtable@MLEint[order(-oadaAICtable@AkaikeWeight),])
  SEs<-as.matrix(oadaAICtable@SEs[order(-oadaAICtable@AkaikeWeight),])
  SEilv<-as.matrix(oadaAICtable@SEilv[order(-oadaAICtable@AkaikeWeight),])
  SEint<-as.matrix(oadaAICtable@SEint[order(-oadaAICtable@AkaikeWeight),])


  #Filter as requested by the user
  if(!is.null(typeFilter)) {
    if(includeAsocial){
      MLEs <-MLEs[printTable$type==typeFilter|printTable$type=="noILVs"|printTable$type=="asocial",]
      MLEilv <-MLEilv[printTable$type==typeFilter|printTable$type=="noILVs"|printTable$type=="asocial",]
      MLEint <-MLEint[printTable$type==typeFilter|printTable$type=="noILVs"|printTable$type=="asocial",]
      AkaikeWeight<-AkaikeWeight[printTable$type==typeFilter|printTable$type=="noILVs"|printTable$type=="asocial"]
      netCombo<-printTable$netCombo[printTable$type==typeFilter|printTable$type=="noILVs"|printTable$type=="asocial"]
    }else{
      MLEs <-MLEs[printTable$type==typeFilter|printTable$type=="noILVs",]
      MLEilv <-MLEilv[printTable$type==typeFilter|printTable$type=="noILVs",]
      MLEint <-MLEint[printTable$type==typeFilter|printTable$type=="noILVs",]
      AkaikeWeight<-AkaikeWeight[printTable$type==typeFilter|printTable$type=="noILVs"]
      netCombo<-printTable$netCombo[printTable$type==typeFilter|printTable$type=="noILVs"]
    }
  }else{netCombo<-printTable$netCombo}

  #Filter by network as requested by the user
  if(!is.null(netFilter)) {
    MLEs <-MLEs[netCombo==netFilter,]
    MLEilv <-MLEilv[netCombo==netFilter,]
    MLEint <-MLEint[netCombo==netFilter,]
    AkaikeWeight<-AkaikeWeight[netCombo==netFilter]
  }

  if(!is.null(typeFilter)) {
    if(includeAsocial){
      SEs <-SEs[printTable$type==typeFilter|printTable$type=="noILVs"|printTable$type=="asocial",]
      SEilv <-SEilv[printTable$type==typeFilter|printTable$type=="noILVs"|printTable$type=="asocial",]
      SEint <-SEint[printTable$type==typeFilter|printTable$type=="noILVs"|printTable$type=="asocial",]
   }else{
      SEs <-SEs[printTable$type==typeFilter|printTable$type=="noILVs",]
      SEilv <-SEilv[printTable$type==typeFilter|printTable$type=="noILVs",]
      SEint <-SEint[printTable$type==typeFilter|printTable$type=="noILVs",]
    }
  }else{netCombo<-printTable$netCombo}
  #Filter by network as requested by the user
  if(!is.null(netFilter)) {
    SEs <-SEs[netCombo==netFilter,]
    SEilv <-SEilv[netCombo==netFilter,]
    SEint <-SEint[netCombo==netFilter,]
  }

	#If nanReplace option is used, then nan for individual model SEs are replaced with a weighted average across all model containing that parameter
	if(nanReplace){
    for(i in 1:dim(SEs)[2]){
  	  SEs[is.nan(SEs[,i]),i]<-sum(SEs[!is.nan(SEs[,i])&(SEs[,i]>0),i]*AkaikeWeight[!is.nan(SEs[,i])&(SEs[,i]>0)])/sum(AkaikeWeight[!is.nan(SEs[,i])&(SEs[,i]>0)])
    }
	  for(i in 1:dim(SEilv)[2]){
	    SEilv[is.nan(SEilv[,i]),i]<-sum(SEilv[!is.nan(SEilv[,i])&(SEilv[,i]>0),i]*AkaikeWeight[!is.nan(SEilv[,i])&(SEilv[,i]>0)])/sum(AkaikeWeight[!is.nan(SEilv[,i])&(SEilv[,i]>0)])
	  }
	  for(i in 1:dim(SEint)[2]){
	    SEint[is.nan(SEint[,i]),i]<-sum(SEint[!is.nan(SEint[,i])&(SEint[,i]>0),i]*AkaikeWeight[!is.nan(SEint[,i])&(SEint[,i]>0)])/sum(AkaikeWeight[!is.nan(SEint[,i])&(SEint[,i]>0)])
	  }
	}

	#Correct Akaike Weights for the new subset of models
	AkaikeWeight<-AkaikeWeight/sum(AkaikeWeight)

	MAvs<-apply(as.matrix(MLEs*AkaikeWeight),2,sum)
	MAvilv<-apply(as.matrix(MLEilv*AkaikeWeight),2,sum)
	MAvint<-apply(as.matrix(MLEint*AkaikeWeight),2,sum)

	modelContributionToSEs<-AkaikeWeight*(SEs^2 + t((t(MLEs)-MAvs))^2)
	modelContributionToSEilv<-AkaikeWeight*(SEilv^2 + t((t(MLEilv)-MAvilv))^2)
	modelContributionToSEint<-AkaikeWeight*(SEint^2 + t((t(MLEint)-MAvint))^2)

	UCSEs<-apply(as.matrix(modelContributionToSEs),2,sum)
	UCSEilv<-apply(as.matrix(modelContributionToSEilv),2,sum)
	UCSEint<-apply(as.matrix(modelContributionToSEint),2,sum)

	return(c(UCSEs, UCSEilv, UCSEint))
}


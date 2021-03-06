plotProfLik<-function(which,model,range,constraintsVect=NULL,resolution=20,iterations=150,inflation=1,conf=0.95,retainInt=NULL){

  if(model@nbdaMultiDiff[1]=="NA"){
	    nbdadata<-model@nbdadata
	  }else{
	    nbdadata<-model@nbdaMultiDiff
	    #return("Please provide specify data underlying this multi diffusion model")
	}
  
  #If there are multiple diffusions "borrow" the first diffusion to extract necessary parameters
  if(is.character(nbdadata)){
    nbdadataTemp<-eval(as.name(nbdadata[1]));
  }else{nbdadataTemp<-nbdadata}
  
  #calculate the number of each type of parameter
  noSParam <- dim(nbdadataTemp@stMetric)[2] #s parameters
  noILVasoc<- dim(nbdadataTemp@asocILVdata)[2] #ILV effects on asocial learning
  noILVint<- dim(nbdadataTemp@intILVdata)[2] #ILV effects on interaction (social learning)
  noILVmulti<- dim(nbdadataTemp@multiILVdata)[2] #ILV multiplicative model effects
  
  if(nbdadataTemp@int_ilv[1]=="ILVabsent") noILVint<-0
  if(nbdadataTemp@asoc_ilv[1]=="ILVabsent") noILVasoc<-0
  if(nbdadataTemp@multi_ilv[1]=="ILVabsent") noILVmulti<-0
    
	type<-fitType<-model@type
	cutoff<-model@loglik+inflation*qchisq(conf,1)/2

	#If it was an asocial model- was the interaction retained?
	if(is.null(retainInt)){
	  if(is.character(nbdadata)){
	    retainInt<-FALSE
	    for (i in 1:length(nbdadata)){
	      nbdadataTemp2<-eval(as.name(nbdadata[i]));
	      if(sum(nbdadataTemp2@offsetCorrection[,1])>0) retainInt<-TRUE
	    }
	  }else{
	    retainInt<-sum(nbdadata@offsetCorrection[,1])>0
	  }  
	}  
	
  #If no constraints vector is specified, then just constrain the parameter being varied to 0 (the add appropriate offset later)
	if(is.null(constraintsVect)) {
		constraintsVect<-model@outputPar*0
		constraintsVect[-which]<-1:(length(constraintsVect)-1)
	}

	#If the model has fitType "asocial"
	#We need to add a one for the s parameters so the constrianed NBDA object can be created
	#And the ILV numbers need shifting up one
	#And which needs incrementing by one too
	if(fitType=="asocial"){
	  constraintsVect<-c(rep(1,noSParam),constraintsVect);
	  constraintsVect[-(1:noSParam)]<-(constraintsVect[-(1:noSParam)]+1)*(constraintsVect[-(1:noSParam)]>0);
	  which<-which+noSParam
	}
	
	#If the user has specified all zeroes for the s parameters, we need to change the fitType to "asocial" 
	#And we need to add a one for the first s parameter so the constrianed NBDA object can be created
	#And the ILV numbers need shifting up one	
	if(sum(constraintsVect[1:noSParam])==0){
	  fitType<-"asocial";
	  constraintsVect[1]<-1;
	  constraintsVect[-(1:noSParam)]<-(constraintsVect[-(1:noSParam)]+1)*(constraintsVect[-(1:noSParam)]>0);
	  if(which<=noSParam&noILVint>0) retainInt<-TRUE
	}

	#Divide up the constraints matrix into components, then add back together to account for interactions in the asocial model
	constraintsSparam<-constraintsVect[(1:noSParam)]
	if(noILVasoc==0){constraintsAsocILV<-NULL}else{constraintsAsocILV<-constraintsVect[(noSParam+1):(noSParam+noILVasoc)]}
  if(type=="asocial"&!retainInt){
    if(noILVint==0){constraintsIntILV<-NULL}else{constraintsIntILV<-rep(0,noILVint)}
    if(noILVmulti==0){constraintsMultiILV<-NULL}else{constraintsMultiILV<-constraintsVect[(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVmulti)]}
    if (which>noSParam+noILVasoc) which<-which+noILVint
  }else{
    if(noILVint==0){constraintsIntILV<-NULL}else{constraintsIntILV<-constraintsVect[(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVint)]}
    if(noILVmulti==0){constraintsMultiILV<-NULL}else{constraintsMultiILV<-constraintsVect[(noSParam+noILVasoc+noILVint+1):(noSParam+noILVasoc+noILVint+noILVmulti)]}
  }
	constraintsVect<-c(constraintsSparam,constraintsAsocILV,constraintsIntILV,constraintsMultiILV)

	#Initialize offsetVect to 0s
	offsetVect<-constraintsVect*0
	
	xVals<-seq(range[1],range[2],length=resolution)
	profLik<-convergence<-rep(NA,length(xVals))	

for(i in 1:length(xVals)){
  offsetVect<-constraintsVect*0
  offsetVect[which]<-xVals[i]
  
		#Create the necessary constrained data objects
		if(is.character(nbdadata)){
		  nbdadataTemp<-paste(nbdadata,"Temp",sep="")
		  for(dataset in 1:length(nbdadata)){
		    assign(nbdadataTemp[dataset],constrainedNBDAdata(nbdadata=eval(as.name(nbdadata[dataset])),constraintsVect=constraintsVect,offsetVect=offsetVect),envir = .GlobalEnv)
		  }
		}else{
		  nbdadataTemp<-constrainedNBDAdata(nbdadata=nbdadata,constraintsVect=constraintsVect,offsetVect=offsetVect)
		}
		
    # This blocked out bit is now being done in the oadaFit_coxme function
		#Fit the model
    #modelTemp<-oadaFit(nbdadata= nbdadataTemp,type=fitType,iterations=iterations,standardErrors=F,coxmeFit=F)
    
    #if(class(model2_RE)=="oadaFit_coxme"){
      #if the model is a coxme fit, we fit a model without random effects first, and use the MLEs as starting values for the coxme fit
    #  startVals<-modelTemp@outputPar[-((length(modelTemp@outputPar)-noILVmulti+1):length(modelTemp@outputPar))]
    #  modelTemp<-oadaFit(nbdadata= nbdadataTemp,type=fitType,iterations=iterations,standardErrors=F,startValue = startVals)
    #}
    
    modelTemp<-oadaFit(nbdadata= nbdadataTemp,type=fitType,iterations=iterations,standardErrors=F)
    
		if(is.null(modelTemp@optimisation$convergence)){
		  convergence[i]<-0
		}else{
		  convergence[i]<-modelTemp@optimisation$convergence
		}
		profLik[i]<-modelTemp@loglik
		plot(xVals[convergence==0],profLik[convergence==0],type="l",xlim=range,ylim=c(model@loglik-(max(na.omit(profLik))-model@loglik)*0.03,max(na.omit(profLik))),xlab=model@varNames[which],ylab="Profile log-likelihood")
    #Plot unconverged points in red
		points(xVals[convergence==1],profLik[convergence==1],col=2)
		abline(h= cutoff, lty=2)
    }
	converged<-rep(NA,length(convergence))
	converged[convergence==0]<-"Yes"
	converged[convergence==1]<-"No"
	return(data.frame(xVals,profLik,converged))	
}

distanceFromCutoff<-function(value,which,model,constraintsVect=NULL,iterations=150,inflation=1,conf=0.95,retainInt=NULL){

  if(model@nbdaMultiDiff[1]=="NA"){
    nbdadata<-model@nbdadata
  }else{
    nbdadata<-model@nbdaMultiDiff
    #return("Please provide specify data underlying this multi diffusion model")
  }
  
  #If there are multiple diffusions "borrow" the first diffusion to extract necessary parameters
  if(is.character(nbdadata)){
    nbdadataTemp<-eval(as.name(nbdadata[1]));
  }else{nbdadataTemp<-nbdadata}
  
  #calculate the number of each type of parameter
  noSParam <- dim(nbdadataTemp@stMetric)[2] #s parameters
  noILVasoc<- dim(nbdadataTemp@asocILVdata)[2] #ILV effects on asocial learning
  noILVint<- dim(nbdadataTemp@intILVdata)[2] #ILV effects on interaction (social learning)
  noILVmulti<- dim(nbdadataTemp@multiILVdata)[2] #ILV multiplicative model effects
  
  if(nbdadataTemp@int_ilv[1]=="ILVabsent") noILVint<-0
  if(nbdadataTemp@asoc_ilv[1]=="ILVabsent") noILVasoc<-0
  if(nbdadataTemp@multi_ilv[1]=="ILVabsent") noILVmulti<-0
  
  type<-fitType<-model@type
  cutoff<-model@loglik+inflation*qchisq(conf,1)/2

  #If it was an asocial model- was the interaction retained?
  if(is.null(retainInt)){
    if(is.character(nbdadata)){
      retainInt<-FALSE
      for (i in 1:length(nbdadata)){
        nbdadataTemp2<-eval(as.name(nbdadata[i]));
        if(sum(nbdadataTemp2@offsetCorrection[,1])>0) retainInt<-TRUE
      }
    }else{
      retainInt<-sum(nbdadata@offsetCorrection[,1])>0
    }  
  }  
  
  #If no constraints vector is specified, then just constrain the parameter being varied to 0 (the add appropriate offset later)
  if(is.null(constraintsVect)) {
    constraintsVect<-model@outputPar*0
    constraintsVect[-which]<-1:(length(constraintsVect)-1)
  }
  
  #If the model has fitType "asocial"
  #We need to add a one for the s parameters so the constrianed NBDA object can be created
  #And the ILV numbers need shifting up one
  #And which needs incrementing by one too
  if(fitType=="asocial"){
    constraintsVect<-c(rep(1,noSParam),constraintsVect);
    constraintsVect[-(1:noSParam)]<-(constraintsVect[-(1:noSParam)]+1)*(constraintsVect[-(1:noSParam)]>0);
    which<-which+noSParam
  }
  
  #If the user has specified all zeroes for the s parameters, we need to change the fitType to "asocial" 
  #And we need to add a one for the first s parameter so the constrianed NBDA object can be created
  #And the ILV numbers need shifting up one	
  if(sum(constraintsVect[1:noSParam])==0){
    fitType<-"asocial";
    constraintsVect[1]<-1;
    constraintsVect[-(1:noSParam)]<-(constraintsVect[-(1:noSParam)]+1)*(constraintsVect[-(1:noSParam)]>0);
  }
  
  #Divide up the constraints matrix into components, then add back together to account for interactions in the asocial model
  constraintsSparam<-constraintsVect[(1:noSParam)]
  if(noILVasoc==0){constraintsAsocILV<-NULL}else{constraintsAsocILV<-constraintsVect[(noSParam+1):(noSParam+noILVasoc)]}
  if(type=="asocial"&!retainInt){
    if(noILVint==0){constraintsIntILV<-NULL}else{constraintsIntILV<-rep(0,noILVint)}
    if(noILVmulti==0){constraintsMultiILV<-NULL}else{constraintsMultiILV<-constraintsVect[(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVmulti)]}
    if (which>noSParam+noILVasoc) which<-which+noILVint
  }else{
    if(noILVint==0){constraintsIntILV<-NULL}else{constraintsIntILV<-constraintsVect[(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVint)]}
    if(noILVmulti==0){constraintsMultiILV<-NULL}else{constraintsMultiILV<-constraintsVect[(noSParam+noILVasoc+noILVint+1):(noSParam+noILVasoc+noILVint+noILVmulti)]}
  }
  constraintsVect<-c(constraintsSparam,constraintsAsocILV,constraintsIntILV,constraintsMultiILV)
  
  
  #Initialize offsetVect to 0s
  offsetVect<-constraintsVect*0

    #Input specified value
  offsetVect[which]<-value
  
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
  modelTemp<-oadaFit(nbdadata= nbdadataTemp,type=fitType,iterations=iterations, standardErrors=F)
	profLik<-modelTemp@loglik
	return(abs(cutoff-profLik))
}

profLikCI<-function(which,model,upperRange=NULL,lowerRange=NULL,constraintsVect=NULL,iterations=150,inflation=1,conf=0.95,retainInt=NULL){
	
	if(!is.null(upperRange)){
			temp1<-optimise(distanceFromCutoff,upperRange,which=which,model=model, constraintsVect= constraintsVect,iterations=iterations,inflation=inflation,conf=conf,retainInt=retainInt)
			upperPoint<-temp1$minimum
		}else{upperPoint<-NA}
	
	#Evaluate at 0
  #In order to do this we record the original values of which and constraintsVect to be used with distanceFromCutOff later
  
  originalWhich<-which;
  originalConstrainstsVect<-constraintsVect;
  
  if(model@nbdaMultiDiff[1]=="NA"){
    nbdadata<-model@nbdadata
  }else{
    nbdadata<-model@nbdaMultiDiff
    #return("Please provide specify data underlying this multi diffusion model")
  }
  
  #If there are multiple diffusions "borrow" the first diffusion to extract necessary parameters
  if(is.character(nbdadata)){
    nbdadataTemp<-eval(as.name(nbdadata[1]));
  }else{nbdadataTemp<-nbdadata}
  
  #calculate the number of each type of parameter
  noSParam <- dim(nbdadataTemp@stMetric)[2] #s parameters
  noILVasoc<- dim(nbdadataTemp@asocILVdata)[2] #ILV effects on asocial learning
  noILVint<- dim(nbdadataTemp@intILVdata)[2] #ILV effects on interaction (social learning)
  noILVmulti<- dim(nbdadataTemp@multiILVdata)[2] #ILV multiplicative model effects
  
  if(nbdadataTemp@int_ilv[1]=="ILVabsent") noILVint<-0
  if(nbdadataTemp@asoc_ilv[1]=="ILVabsent") noILVasoc<-0
  if(nbdadataTemp@multi_ilv[1]=="ILVabsent") noILVmulti<-0
  
  type<-fitType<-model@type
  cutoff<-model@loglik+inflation*qchisq(conf,1)/2

  #If it was an asocial model- was the interaction retained?
  originalRetainInt<-retainInt
  if(is.null(retainInt)){
    if(is.character(nbdadata)){
      retainInt<-FALSE
      for (i in 1:length(nbdadata)){
        nbdadataTemp2<-eval(as.name(nbdadata[i]));
        if(sum(nbdadataTemp2@offsetCorrection[,1])>0) retainInt<-TRUE
      }
    }else{
      retainInt<-sum(nbdadata@offsetCorrection[,1])>0
    }  
  }  
  
  #If no constraints vector is specified, then just constrain the parameter being varied to 0 (the add appropriate offset later)
  if(is.null(constraintsVect)) {
    constraintsVect<-model@outputPar*0
    constraintsVect[-which]<-1:(length(constraintsVect)-1)
  }
  
  #If the model has fitType "asocial"
  #We need to add a one for the s parameters so the constrianed NBDA object can be created
  #And the ILV numbers need shifting up one
  #And which needs incrementing by one too
  if(fitType=="asocial"){
    constraintsVect<-c(rep(1,noSParam),constraintsVect);
    constraintsVect[-(1:noSParam)]<-(constraintsVect[-(1:noSParam)]+1)*(constraintsVect[-(1:noSParam)]>0);
    which<-which+noSParam
  }
  
  #If the user has specified all zeroes for the s parameters, we need to change the fitType to "asocial" 
  #And we need to add a one for the first s parameter so the constrianed NBDA object can be created
  #And the ILV numbers need shifting up one	
  if(sum(constraintsVect[1:noSParam])==0){
    fitType<-"asocial";
    constraintsVect[1]<-1;
    constraintsVect[-(1:noSParam)]<-(constraintsVect[-(1:noSParam)]+1)*(constraintsVect[-(1:noSParam)]>0);
  }
  
  #Divide up the constraints matrix into components, then add back together to account for interactions in the asocial model
  constraintsSparam<-constraintsVect[(1:noSParam)]
  if(noILVasoc==0){constraintsAsocILV<-NULL}else{constraintsAsocILV<-constraintsVect[(noSParam+1):(noSParam+noILVasoc)]}
  if(type=="asocial"&!retainInt){
    if(noILVint==0){constraintsIntILV<-NULL}else{constraintsIntILV<-rep(0,noILVint)}
    if(noILVmulti==0){constraintsMultiILV<-NULL}else{constraintsMultiILV<-constraintsVect[(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVmulti)]}
    if (which>noSParam+noILVasoc) which<-which+noILVint
  }else{
    if(noILVint==0){constraintsIntILV<-NULL}else{constraintsIntILV<-constraintsVect[(noSParam+noILVasoc+1):(noSParam+noILVasoc+noILVint)]}
    if(noILVmulti==0){constraintsMultiILV<-NULL}else{constraintsMultiILV<-constraintsVect[(noSParam+noILVasoc+noILVint+1):(noSParam+noILVasoc+noILVint+noILVmulti)]}
  }
  constraintsVect<-c(constraintsSparam,constraintsAsocILV,constraintsIntILV,constraintsMultiILV)
  
  #Initialize offsetVect to 0s
  offsetVect<-constraintsVect*0
  #Input specified value
  offsetVect[which]<-0
  
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
  modelTemp<-oadaFit(nbdadata= nbdadataTemp,type=fitType,iterations=iterations, standardErrors=F)
  profLik<-modelTemp@loglik


  
if(is.null(lowerRange)){
	if(profLik<cutoff){lowerPoint<-0}else{lowerPoint <-NA}
}else{
  #Put the original values of constraintsVect and which back
  originalRetainInt->retainInt
  originalWhich->which;
  originalConstrainstsVect->constraintsVect;
  temp2<-optimise(distanceFromCutoff, lowerRange,which=which,model=model, constraintsVect= constraintsVect, iterations=iterations,inflation=inflation,conf=conf,retainInt=retainInt)
  lowerPoint<-temp2$minimum
}

	output<-c(lowerPoint,upperPoint)
	names(output)<-list("Lower CI","Upper CI")
	return(output)
}



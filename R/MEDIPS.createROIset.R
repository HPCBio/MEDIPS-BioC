##########################################################################
##Creates MEDIPS SET of type S4 from input data (i.e. aligned short reads)
##########################################################################
##Input:	bam file or tab (|) separated BED txt file
##Param:	[path]+file name, [path]+file roi name, extend, shift, window_size, BSgenome, uniq (T | F), chr.select
##Output:	MEDIPS SET
##Requires:	gtools, BSgenome
##Modified:	11/10/2012
##Author:	Lukas Chavez

MEDIPS.createROIset <- function(file=NULL, ROI=NULL, extend=0, shift=0, bn=1, BSgenome=NULL, uniq=TRUE, chr.select=NULL, paired=F, sample_name=NULL){
			
	## Proof of correctness....
	if(is.null(BSgenome)){stop("Must specify a BSgenome library.")}
	if(is.null(file)){stop("Must specify a bam or txt file.")}
		
	## Read region file		
	fileName=unlist(strsplit(file, "/"))[length(unlist(strsplit(file, "/")))]
	path=paste(unlist(strsplit(file, "/"))[1:(length(unlist(strsplit(file, "/"))))-1], collapse="/") 
	if(path==""){path=getwd()}
		
	if(!fileName%in%dir(path)){stop(paste("File", fileName, " not found in", path, sep =" "))}
	
	if(!paired){GRange.Reads = getGRange(fileName, path, extend, shift, chr.select, uniq,ROI)}
	else{GRange.Reads = getPairedGRange(fileName, path, extend, shift, chr.select, uniq,ROI)}
				
	## Sort chromosomes
	if(length(unique(seqlevels(GRange.Reads)))>1)
		chromosomes=mixedsort(unique(seqlevels(GRange.Reads)))
	else
		chromosomes=unique(seqlevels(GRange.Reads))
	
	## Get chromosome lengths for all chromosomes within data set.
	cat(paste("Loading chromosome lengths for ",BSgenome, "...\n", sep=""))		
	dataset=get(ls(paste("package:", BSgenome, sep="")))
	#chr_lengths=as.numeric(sapply(chromosomes, function(x){as.numeric(length(dataset[[x]]))}))
	chr_lengths=as.numeric(seqlengths(dataset)[chromosomes])	

	## Create the ROI Granges object	
	ROI = data.frame(chr=as.character(ROI[,1]), start=ROI[,2], end=ROI[,3], ID=as.character(ROI[,4]))
        Granges.genomeVec  = bin.ROIs(ROI=ROI, binNo=bn)
		
	##Distribute reads over genome
	cat("Calculating short read coverage for genome wide windows...\n")
	overlap = countOverlaps(Granges.genomeVec, GRange.Reads)

	##Set sample name
	if(is.null(sample_name)){
		sample_name = fileName
	}
			
	## creating MEDIPSset object
    	MEDIPSroiSetObj = new('MEDIPSroiSet', sample_name=sample_name,
				                        path_name=path,
				                        genome_name=BSgenome, 
							number_regions=length(GRange.Reads), 
							chr_names=chromosomes, 
							chr_lengths=chr_lengths, 
							genome_count=overlap, 
							extend=extend,
							shifted=shift, 
							bin_number=bn,
							uniq=uniq,
							ROI=Granges.genomeVec)
    	gc()
	return(MEDIPSroiSetObj) 	
}


#####################################
##Create intervals of given regions
#####################################
##Input: matrix containing genomic regions
##Param: number of bins
##Output: GRanges object where for each range a 'number of bins' number of regions was created
##Modified: 14/10/2011
##Author: Lukas Chavez
bin.ROIs = function(ROI=NULL, binNo=NULL){
	
	chr=as.character(ROI[,1])
	start=as.numeric(ROI[,2])
	stop=as.numeric(ROI[,3])
	name=as.character(ROI[,4])	
	
	result.ext = matrix(ncol=4, nrow=length(chr)*binNo)

	if(binNo>1){
		for(i in 1:length(chr)){
		
			interval.positions = floor(seq(start[i], stop[i], length.out=binNo+1))
			start.ext=interval.positions[c(1:length(interval.positions)-1)]
			start.ext[2:length(start.ext)]=start.ext[2:length(start.ext)]+1
			stop.ext=interval.positions[c(2:length(interval.positions))]
	
			result.ext[c(((i-1)*binNo+1):(i*binNo)),1] = chr[i]	
			result.ext[c(((i-1)*binNo+1):(i*binNo)),2] = start.ext
			result.ext[c(((i-1)*binNo+1):(i*binNo)),3] = stop.ext	
			result.ext[c(((i-1)*binNo+1):(i*binNo)),4] = paste(name[i], seq(1,binNo), sep="_")	
		}
	} else{
		result.ext[,1] = chr
		result.ext[,2] = start
		result.ext[,3] = stop
		result.ext[,4] = name		
	}
	
	binROIs = GRanges(seqnames=result.ext[,1], ranges=IRanges(start=as.numeric(result.ext[,2]), end=as.numeric(result.ext[,3]), names=result.ext[,4]))
	
	return(binROIs)

}


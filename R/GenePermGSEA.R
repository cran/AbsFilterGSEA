if(is.loaded("OnetailedGSEA",type = "External")){print("Function 'OnetailedGSEA' is properly loaded")}
if(is.loaded("TwotailedGSEA",type = "External")){print("Function 'TwotailedGSEA' is properly loaded")}

Onetailed = function(tvalue, genesetfile, min, max, nPerm, cutoff, q){
  .Call("OnetailedGSEA", tvalue, genesetfile, min, max, nPerm, cutoff, q)
}

Twotailed = function(tvalue, genesetfile, min, max, nPerm, cutoff, q){
  .Call("TwotailedGSEA", tvalue, genesetfile, min, max, nPerm, cutoff, q)
}

snr = function(value, g1, g2){
  meandiff = mean(value[g1])-mean(value[g2])
  sdsum = sd(value[g1])+sd(value[g2])
  result = meandiff/sdsum
  return(result)
}

foldchange = function(value, g1, g2)
{
  val1 = mean(value[g1])
  val2 = mean(value[g2])
  if(val1 == 0){val1 = val1+(0.0001/length(g1))}
  if(val2 == 0){val2 = val2+(0.0001/length(g2))}
  result = log2(val1/val2)
  return(result)
}

ranksum = function(value, g1, g2)
{
  ORDER = rank(value, ties.method='average')
  len1 = length(g1)
  len2 = (length(g1)+length(g2))+1
  Tvalue = sum(ORDER[g1])-(len1*len2/2)
  return(Tvalue)
}

#' Gene permuting GSEA with or without filtering by absolute GSEA.
#'
#' Gene-permuting GSEA (or preranked GSEA) generates a lot of false positive gene-sets due to the inter-gene correlation in each gene set. Such false positives can be successfully reduced by filtering with the one-tailed absolute GSEA results. This function provides gene-permuting GSEA calculation with or without the absolute filtering.
#'
#' @param countMatrix Normalized RNA-seq read count matrix.
#'
#' @param GeneScoreType Type of gene score. Possible gene score is "SNR", "FC" (log fold change score) or "RANKSUM" (zero centered).
#'
#' @param idxCase Indices for case samples in the count matrix. e.g., 1:5
#'
#' @param idxControl Indices for control samples in the count matrix. e.g., 6:10
#'
#' @param GenesetFile File path for gene set file. Typical GMT file or its similar 'tab-delimited' file is available. e.g., "C:/geneset.gmt"
#'
#' @param minGenesetSize Minimum size of gene set allowed. Gene-sets of which sizes are below this value are filtered out from the analysis. Default = 10
#'
#' @param maxGenesetSize Maximum size of gene set allowed. Gene-sets of which sizes are larger this value are filtered out from the analysis. Default = 300
#'
#' @param q Weight exponent for gene score. For example, if q=0, only rank of gene score is reflected in calculating gene set score (preranked GSEA). If q=1, the gene score itself is used. If q=2, square of the gene score is used.
#'
#' @param nPerm The number of gene permutation. Default = 1000.
#'
#' @param GSEAtype Type of GSEA. Possible value is "absolute", "original" or "absFilter". "absolute" for one-tailed absolute GSEA. "original" for the original two-tailed GSEA. "absFilter" for the original GSEA filtered by the results from the one-tailed absolute GSEA.
#'
#' @param FDR FDR cutoff for the original or absolute GSEA. Default = 0.05
#'
#' @param FDRfilter FDR cutoff for the one-tailed absolute GSEA for filtering. Default = 0.05
#'
#' @import Rcpp
#'
#' @importFrom stats sd
#'
#' @return GSEA result table sorted by FDR Q-value.
#'
#' @examples
#'
#' data(example)
#'
#' # Create a gene set file and save it to your local directory.
#' # Note that you can use your local gene set file (tab-delimited) directly.
#' # But here, we will generate a toy gene set file to show the structure of this gene set file.
#' # It consists of 100 gene sets and each contains 100 genes.
#'
#' for(Geneset in 1:100)
#' {
#'    GenesetName = paste("Geneset", Geneset, sep = "_")
#'   Genes = paste("Gene", (Geneset*50-49):(Geneset*50), sep="", collapse = '\t')
#'   Geneset = paste(GenesetName, Genes, sep = '\t')
#'   write(Geneset, file = "geneset.txt", append = TRUE, ncolumns = 1)
#' }
#'
#' # Run Gene-permuting GSEA
#' RES = GenePermGSEA(countMatrix = example, GeneScoreType = "FC", idxCase = 1:5,
#'                    idxControl = 6:10, GenesetFile = 'geneset.txt', GSEAtype = "absFilter")
#' RES
#'
#' @export
#'
#' @details Typical usages are
#' GenePermGSEA(countMatrix = countMatrix, GeneScoreType = "FC", idxCase = 1:5,
#'                    idxControl = 6:10, GenesetFile = 'geneset.txt', GSEAtype = "absFilter")
#'
#' @source Nam, D. Effect of the absolute statistic on gene-sampling gene-set analysis methods. Stat Methods Med Res 2015.
#' Subramanian, A., et al. Gene set enrichment analysis: A knowledge-based approach for interpreting genome-wide expression profiles. P Natl Acad Sci USA 2005;102(43):15545-15550.
#' Li, J. and Tibshirani, R. Finding consistent patterns: A nonparametric approach for identifying differential expression in RNA-Seq data. Statistical Methods in Medical Research 2013;22(5):519-536.
#'
#' @references Nam, D. Effect of the absolute statistic on gene-sampling gene-set analysis methods. Stat Methods Med Res 2015.
#' Subramanian, A., et al. Gene set enrichment analysis: A knowledge-based approach for interpreting genome-wide expression profiles. P Natl Acad Sci USA 2005;102(43):15545-15550.
#' Li, J. and Tibshirani, R. Finding consistent patterns: A nonparametric approach for identifying differential expression in RNA-Seq data. Statistical Methods in Medical Research 2013;22(5):519-536.
#'
#' @useDynLib AbsFilterGSEA
GenePermGSEA = function(countMatrix, GeneScoreType, idxCase, idxControl, GenesetFile, minGenesetSize=10, maxGenesetSize=300, q=1, nPerm=1000, GSEAtype="absFilter", FDR=0.05, FDRfilter=0.05)
{
  dimMat = dim(countMatrix)
  if(dimMat[1]*dimMat[2] == 0){stop("Count matrix must have positive dimension.")}
  if(GeneScoreType!="SNR" & GeneScoreType!="FC" & GeneScoreType!="RANKSUM"){stop("Gene score type must be 'SNR', 'FC' or 'RANKSUM'.")}
  if(length(idxCase)<1 | length(idxControl)<1){stop("idxCase and idxControl must be positive integer.")}
  if(!file.exists(GenesetFile)){stop("Such gene set file does not exist.")}
  if(GSEAtype!="absolute" & GSEAtype !="original" & GSEAtype!="absFilter"){stop("GSEAtype must be 'absolute' (for absolute GSEA), 'original' (both up and down direction) or 'absFilter' (Result for two-tailed GSEA filtered by one-tailed GSEA result).")}

  countMatrix = data.matrix(countMatrix)
  # Gene score
  if(GeneScoreType == 'SNR')
  {
    FUNC = snr
  }
  if(GeneScoreType == 'FC')
  {
    FUNC = foldchange
  }
  if(GeneScoreType == 'RANKSUM')
  {
    FUNC = ranksum
  }
  genescore = try(apply(countMatrix, 1, FUN = FUNC, g1 = idxCase, g2 = idxControl), silent = T)
  if(class(genescore)=='try-error'){stop("Invalid gene scores")}
  genescore = sort(genescore, decreasing = TRUE)

  if(GSEAtype == "Onetailed" | GSEAtype == "absFilter"){genescore_abs = abs(genescore); genescore_abs = sort(genescore_abs, decreasing = TRUE)}

  # GSEA
  if(GSEAtype == "Onetailed")
  {
    Result_table = Onetailed(genescore_abs, GenesetFile, minGenesetSize, maxGenesetSize, nPerm, FDR, q)
    Result_table = Result_table[order(Result_table[[5]]),]
    return(Result_table)
  }

  if(GSEAtype == "Twotailed")
  {
    Result_table = Twotailed(genescore, GenesetFile, minGenesetSize, maxGenesetSize, nPerm, FDR, q)
    Result_table = Result_table[order(Result_table[[5]]),]
    return(Result_table)
  }

  if(GSEAtype == "absFilter")
  {
    Result_table_abs = Onetailed(genescore_abs, GenesetFile, minGenesetSize, maxGenesetSize, nPerm, FDRfilter, q)
    Result_table_ord = Twotailed(genescore, GenesetFile, minGenesetSize, maxGenesetSize, nPerm, FDR, q)
    Filtered = which(Result_table_ord$GenesetName%in%Result_table_abs$GenesetName)
    Result_table = Result_table_ord[Filtered,]
    Result_table = Result_table[order(Result_table[[5]]),]
    return(Result_table)
  }
}
// Author: Johannes F. Schmieder
// Department of Economics, Columbia University
// Comments and suggestions welcome: jfs2106 {at} columbia.edu
// Updated 12 April 2012 by Kyle Foreman to remove equals signs/quotes

capture program drop mat2csv
capture program drop QuotedFullnames
program define mat2csv
version 9
syntax , Matrix(name) SAVing(str) [ REPlace APPend Title(str) SUBTitle(str) Format(str) NOTe(str) SUBNote(str) COLumnnames(string asis) ROWlabels(string asis)]
* if "`format'"=="" local format "%10.0g"
local formatn: word count `format'
local saving: subinstr local saving "." ".", count(local ext)
if !`ext' local saving "`saving'.csv"
tempname myfile
file open `myfile' using "`saving'", write text `append' `replace'
local nrows=rowsof(`matrix')
local ncols=colsof(`matrix')

QuotedFullnames `matrix' row
QuotedFullnames `matrix' col
if `"`columnnames'"'!="" {
  local colnames `columnnames'
}

if `"`rowlabels'"'!="" {
  local rownames `rowlabels'
}


if "`title'"!="" {
        file write `myfile' `"="`title'""' _n
}
if "`subtitle'"!="" {
        file write `myfile' `"="`subtitle'""' _n
}

file write `myfile' `"row"'
foreach colname of local colnames {
        file write `myfile' `",`colname'"' 
}
file write `myfile' _n
forvalues r=1/`nrows' {
        local rowname: word `r' of `rownames'
        file write `myfile' `"`rowname'"'
        forvalues c=1/`ncols' {
                if `c'<=`formatn' local fmt: word `c' of `format'
		  file write `myfile' `","'
                file write `myfile' `fmt' (`matrix'[`r',`c']) 
		  file write `myfile' `""'
        }
        file write `myfile' _n
}
if "`note'"!="" {
file write `myfile' `"`note'"' _n
}
if "`subnote'"!="" {
file write `myfile' `"`subnote'"' _n
}
file close `myfile'
end

program define QuotedFullnames
        args matrix type
        tempname extract
        local one 1
        local i one
        local j one
        if "`type'"=="row" local i k
        if "`type'"=="col" local j k
        local K = `type'sof(`matrix')
        forv k = 1/`K' {
                mat `extract' = `matrix'[``i''..``i'',``j''..``j'']
                local name: `type'names `extract'
                local eq: `type'eq `extract'
                if `"`eq'"'=="_" local eq
                else local eq `"`eq':"'
                local names `"`names'`"`eq'`name'"' "'
        }
        c_local `type'names `"`names'"'
end

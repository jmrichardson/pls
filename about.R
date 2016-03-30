library(shiny)
library(shinyBS)

# PLS Version
plsVersion="7.904"

source('popup.R')

msg=paste('Peer Lending Server<b>', plsVersion, '</b><br>Copyright 2014 Lending Crunch Tech LLC<br>All rights reserved')
popup(msg,500,190,"About")

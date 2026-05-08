`ifndef CSR_DEFINES_VH
`define CSR_DEFINES_VH

`define CSR_CRMD        14'h000
`define CSR_PRMD        14'h001
`define CSR_EUEN        14'h002
`define CSR_ECFG        14'h004
`define CSR_ESTAT       14'h005
`define CSR_ERA         14'h006
`define CSR_BADV        14'h007
`define CSR_EENTRY      14'h00c
`define CSR_TLBIDX      14'h010
`define CSR_TLBEHI      14'h011
`define CSR_TLBELO0     14'h012
`define CSR_TLBELO1     14'h013
`define CSR_ASID        14'h018
`define CSR_PGDL        14'h019
`define CSR_PGDH        14'h01a
`define CSR_PGD         14'h01b
`define CSR_CPUID       14'h020
`define CSR_SAVE0       14'h030
`define CSR_SAVE1       14'h031
`define CSR_SAVE2       14'h032
`define CSR_SAVE3       14'h033
`define CSR_TID         14'h040
`define CSR_TCFG        14'h041
`define CSR_TVAL        14'h042
`define CSR_TICLR       14'h044
`define CSR_LLBCTL      14'h060
`define CSR_TLBRENTRY   14'h088
`define CSR_CTAG        14'h098
`define CSR_DMW0        14'h180
`define CSR_DMW1        14'h181


`define CSR_CRMD_PLV     1: 0
`define CSR_CRMD_IE      2: 2
`define CSR_PRMD_PPLV    1: 0
`define CSR_PRMD_PIE     2: 2
`define CSR_ESTAT_IS10   1: 0
`define CSR_ERA_PC      31: 0
`define CSR_EENTRY_VA   31: 6
`define CSR_SAVE_DATA   31: 0
`define CSR_TICLR_CLR    0: 0

`endif // CSR_DEFINES_VH
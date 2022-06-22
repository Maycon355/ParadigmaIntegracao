#include "protheus.ch"
#include "apWebSrv.ch"
#include "RWMAKE.CH"
#include "tbiconn.CH"
#include 'FWMVCDEF.ch'
#include 'RestFul.CH'
#include 'TopConn.CH'
#include "FWMBROWSE.CH"

#define CRLF Chr(13)+Chr(10)

/*/{Protheus.doc} PAR001
//Rotina de integra??o de cadastros
@author fabricio.reche
@since 07/08/2019
@version 1.0

@type function
/*/
user function PAR001(aParam)
	Local bProcess := {|oProcess| lExecuta(oProcess)}
	Local aButtons := {} //rotinas adicionais
	Local cDescAux := "Integrando"
	Local cRotina  := "PAR001"
	Local cTitulo  := "Integracao Protheus x Paradigma"
	Local cDescri  := "Esta rotina efetua as integracoes entre o sistema Protheus e o portal Paradigma"
	Local cPerg    := "PAR001"

	Private lerro   := .F.
	Private aMvPar  := {}
	Private aEmpFil := FWLoadSM0()

	AjustaPerg(cPerg)

	If IsBlind()
		Eval(bProcess)
		Return
	EndIf

	tNewProcess():New(cRotina ,;
		cTitulo ,;
		bProcess,;
		cDescri ,;
		cPerg   ,;
		aButtons,;
		.T.     ,;
		5       ,;
		cDescAux,;
		.T.      )

Return

/*/{Protheus.doc} lExecuta
//Execu??o do processo de integra??o
@author fabricio.reche
@since 07/08/2019
@version 1.0
@Return lRetorno, Indica se o processamento ocorreu corretamente
@param oProcess, object, Objeto tNewProcess instanciado
@type function
/*/
Static Function lExecuta(oProcess)
	Local cInicio    := Time()
	Local aRegSB1    := {}
	Local nProc      := 0
	Local cLog       := ""
	Local oLog       := Nil
	Local oWsEmpresa := Nil
	local nx

	If ! lLockRot()
		Return .F.
	EndIf

	dbSelectArea("ZP1")
	dbSelectArea("ZPL")
	SetRegua1(oProcess, 16)
	IncRegua1(oProcess, "Integrando Empresas")

	If GetMv("MV_XPAREMP") == 2
		oLog       := FwParLog():New("PAR001", "RetornarEmpresaPorCnpj")
		oWsEmpresa := WSEmpresa():New()

		SetRegua2(oProcess, 0)
		IncRegua2(oProcess, "Verificando Empresa")
		//verIfica se a empresa est? cadastrada no sistema
		//If oWsEmpresa:RetornarEmpresaPorCnpj(AllTrim(SM0->M0_CGC))
		If oWsEmpresa:RetornarEmpresaPorCnpj(AllTrim(FWSM0Util():GetSM0Data(cEmpAnt,cFilAnt,{'M0_CGC'})[1][2]))

			//se n?o estiver, chama a fun??o de processar empresa
			If Empty(oWsEmpresa:oWsRetornarEmpresaPorCnpjResult:cScdEmpresa)
				fEmpresa(oProcess, @nProc,  cEmpAnt,cFilAnt   )
			EndIf
		Else
			fSoapFault(oLog)
		EndIf
	Else
       /*
		aAreaSM0 := SM0->(GetArea())
		SM0->(dbSetOrder(1))
		SM0->(dbSeek("01"))
		
		While !SM0->(EOF())
			fEmpresa(oProcess, @nProc)
			
			SM0->(DbSkip())		
		EndDo

		RestArea(aAreaSM0)
        */

		aRetSM0	:= FWLoadSM0()
		For nx:=1 to len(aRetSM0)
			fEmpresa(oProcess, @nProc,aRetSM0[nx,1],aRetSM0[nx,2])

		next nx


		//Par?metro Integra Empresa Paradigma
		PutMv("MV_XPAREMP", 2) //2=N?o
	EndIf

	IncRegua1(oProcess, "Integrando Moedas")
	//integra??o da moeda
	If GetMv("MV_XPARMOE") <> 2
		nProc += nMoeda(oProcess)
	EndIf

	IncRegua1(oProcess, "Integrando Cotacao Moedas")
	If lMvPar("Cotacao Moeda")
		nProc += nMoedaCota(oProcess)
	EndIf

	IncRegua1(oProcess, "Integrando Categorias")
	//integra??o de categorias
	If lMvPar("Categoria")
		nProc += nCategoria(oProcess)
	EndIf

	IncRegua1(oProcess, "Integrando Usuarios")
	//integra??o da Usu?rio
	If lMvPar("Usuario")
		nProc += nUsuario(oProcess)
	EndIf

	IncRegua1(oProcess, "Integrando Bancos")
	//integra??o de banco
	If lMvPar("Banco")
		nProc += nBanco(oProcess) //oBanco:cScdBanco
	EndIf

	IncRegua1(oProcess, "Integrando Unidades de Medidas")
	//integra??o de unidades de medidas
	If lMvPar("Unidade de Medida")
		nProc += nUnidMed(oProcess)
	EndIf

	IncRegua1(oProcess, "Integrando Condicoes de Pagamentos")
	//integra??o de condi??es de pagamentos
	If lMvPar("Condicao de pagamento")
		nProc += nCondPgto(oProcess)
	EndIf

	IncRegua1(oProcess, "Integrando Centros de Custos")
	//integra??o de centros de custos
	If lMvPar("Centro de Custo")
		nProc += nCentroCus(oProcess)
	EndIf

	IncRegua1(oProcess, "Integrando Conta Contabil")
	//integra??o de conta contabil
	If lMvPar("Conta Contabil")
		nProc += nContaContab(oProcess)
	EndIf

	IncRegua1(oProcess, "Integrando Produtos")
	//integra??o de produtos

	If lMvPar("Produto")
		aRegSB1 := aProdutos(oProcess)
		nProc += Len(aRegSB1)

	EndIf

	IncRegua1(oProcess, "Integrando Segunda Unidade Medida")
	//integra??o da segunda unidade de medida
	If !Empty(aRegSB1)  //lMvPar("Segunda Unidade Medida") .And.
		nProc += nSegUnidMe(oProcess, aRegSB1)
	EndIf

	IncRegua1(oProcess, "Integrando Grupo Compra")
	If lMvPar("Grupo Compra")
		nProc += nGrupComp(oProcess)
	EndIf

	IncRegua1(oProcess, "Integrando Fornecedores")
	//integra??o dos fornecedores
	If lMvPar("Fornecedor")
		nProc += nRetFornec(oProcess)
		nProc += nProcForn(oProcess)
	EndIf

	IncRegua1(oProcess, "Integrando Solicitacoes de Compras")
	//integra??o das solicita??es de compras
	If lMvPar("Solicitacao de Compra")
		nProc += nCancelSC(oProcess)
		nProc += nProcSC(oProcess)
	EndIf

	IncRegua1(oProcess, "Integrando Pedidos de Compras")
	//integra??o das pedidos de compras
	If lMvPar("Pedido de Compra")
		fHabilita()
		nProc += nCancelPC(oProcess)
		nProc += nPCCancel(oProcess)
		nProc += nRetCotaca(oProcess)
		nProc += nEnviaPC(oProcess)
	EndIf

	//libera o lock da rotina
	lUnLockRot()

	If nProc > 0
		cLog := cValToChar(nProc) + " processo(s) executado(s). Tempo decorrido: " + ElapTime(cInicio, Time()) + Iif(lerro, ' Erros Ocorridos!', '')
		lUnLockRot()
	Else
		cLog := Iif(lerro, 'Erros Ocorridos!', "Nada processado")
		lUnLockRot()
	EndIf

	If ! IsBlind()
		lUnLockRot()
		oProcess:SaveLog(cLog)
		MsgInfo(cLog, "Processo Finalizado")
	EndIf

Return .T.

Static Function fEmpresa(oProcess, nProc, cEmpx,cFilx)
	Local oWsEmpresa := WSEmpresa():New()
	Local oEmpresa   := Nil
	Local oLog       := FwParLog():New("PAR001", "ProcessarEmpresa")
	Local aEnd       :=Separa(FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_ENDENT'})[1][2], ",", .F.)  // Separa(SM0->M0_ENDENT, ",", .F.)
	Local cEmail     := GetMv("MV_XPAREMA")
	//Local nTipo      := GetMv("MV_XPARTIP")
	Local cCod       := ''
	Local oError     := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'SM0', @oLog, @cCod)})

	aSize(aEnd, 2)

	Begin Sequence

		SetRegua2(oProcess, 0)
		IncRegua2(oProcess, "Processando Empresa")

		//cCod := SM0->M0_CODIGO + SM0->M0_CODFIL
		cCod := FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_CODIGO'})[1][2] + FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_CODFIL'})[1][2]

//	IncRegua2(oProcess, "Processando " + SM0->M0_CODIGO + SM0->M0_CODFIL)
		IncRegua2(oProcess, "Processando " +  FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_CODIGO'})[1][2] + FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_CODFIL'})[1][2]  )
		fIniLog("Empresa")

		oEmpresa    := Empresa_EmpresaDTO():New()

		oEmpresa:csDsCep                  :=  AllTrim(FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_CEPENT'})[1][2])  //AllTrim(SM0->M0_CEPENT)
		//oEmpresa:csDsUrl                := string
		oEmpresa:csNrFax                  := AllTrim(	FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_FAX'})[1][2]) //AllTrim(SM0->M0_FAX)
		oEmpresa:nnCdTipo                 := 2  //Compradora
		oEmpresa:csNrCnpj                 := AllTrim(FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_CGC'})[1][2]) //AllTrim(SM0->M0_CGC)
		oEmpresa:csSgPais                 := "BR"
		//oEmpresa:csCdCnae                 := SM0->M0_CNAE
		//oEmpresa:csCdMoeda                := "1"
		oEmpresa:nnCdIdioma               := 1
		oEmpresa:csSgEstado               := AllTrim(FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_ESTENT'})[1][2]) //AllTrim(SM0->M0_ESTENT)
		oEmpresa:csNmBairro               := AllTrim(FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_BAIRENT'})[1][2]) //AllTrim(SM0->M0_BAIRENT)
		oEmpresa:csNmCidade               := AllTrim(Capital(Lower(AllTrim(FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_CIDENT'})[1][2]))))//AllTrim(Capital(Lower(AllTrim(SM0->M0_CIDENT))))
		oEmpresa:csCdEmpresa              := FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_CGC'})[1][2] //SM0->M0_CGC
		//oEmpresa:csNmContato            := ""
		oEmpresa:csNmEmpresa              := AllTrim(FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_NOMECOM'})[1][2])//AllTrim(SM0->M0_FILIAL)
		//oEmpresa:csNrCelular            := string
		//oEmpresa:csNmApelido            := string
		oEmpresa:csNmFantasia             := AllTrim(FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_FILIAL'})[1][2]) //AllTrim(SM0->M0_FILIAL)
		oEmpresa:csNrTelefone             := AllTrim(FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_TEL'})[1][2]) //AllTrim(SM0->M0_TEL)
		cxDtre:=FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_TEL'})[1][2]
		oEmpresa:ctDtCadastro             := FwTimeStamp(3, IIf(Empty(cxDtre), cToD('01/01/2018'), cxDtre)) //FwTimeStamp(3, IIf(Empty(SM0->M0_DTRE), cToD('01/01/2018'), SM0->M0_DTRE))
		oEmpresa:csDsEndereco             := aEnd[1]
		oEmpresa:csNrEndereco             := aEnd[2]
		oEmpresa:nnCdSituacao             := 1  //ativa
		oEmpresa:nnIdTipoPessoa           := 2
		//oEmpresa:nnCdEmpresaWbc         := long
		oEmpresa:csNrCnpjMatriz           := FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_CGC'})[1][2]//SM0->M0_CGC
		//oEmpresa:csSgGrupoConta         := string
		oEmpresa:csDsEmailContato         := AllTrim(cEmail)
		//oEmpresa:csCdEmpresaEnvio       := string
		//oEmpresa:csCdAtividadeMap       := string
		//oEmpresa:nnIdSuperSimples       := int
		//oEmpresa:ndVlCapitalSocial      := decimal
		//oEmpresa:nnNrAutoAvaliacao      := int
		//oEmpresa:nnNrNotaAvaliacao      := decimal
		//oEmpresa:csCdEmpresaCliente     := string
		//oEmpresa:nbFlAreaInfluencia     := int
		//oEmpresa:ctDtIntegralizacao     := dateTime
		//oEmpresa:ctDtInicioAtividade    := dateTime
		//oEmpresa:nnCdTipoCadastroMap    := int
		//oEmpresa:ctDtValidadeCadastro   := dateTime
		//oEmpresa:nbFlAtividadeServico   := int
		//oEmpresa:csCdNaturezaJuridica   := string
		//oEmpresa:csCdUsarioHomologador  := string
		oEmpresa:csNrInscricaoEstadual    :=alltrim(FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_INSC'})[1][2]) //AllTrim(SM0->M0_INSC)
		//oEmpresa:ndVlPatrimonioLiquido  := decimal
		oEmpresa:csNrInscricaoMunicial    := alltrim(FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_INSCM'})[1][2]) //AllTrim(SM0->M0_INSCM)
		//oEmpresa:nbFlAtividadeComercial := int
		oEmpresa:csDsEnderecoComplemento  := alltrim(FWSM0Util():GetSM0Data(cEmpx,cFilx,{'M0_COMPENT'})[1][2])//AllTrim(SM0->M0_COMPENT)
		//oEmpresa:nbFlAtividadeIndustrial := int
		//oEmpresa:ndVlCapitalIntegralizado := decimal
		//oWsEmpresa:oWSlstDocumento         := Empresa_ArrayOfCrcHistoricoDTO
		//oEmpresa:oWSlstEmpresaBanco         := Empresa_ArrayOfEmpresaBancoDTO
		//oEmpresa:oWSlstEmpresaClasse         := Empresa_ArrayOfEmpresaClasseDTO
		//oEmpresa:oWSlstEmpresaContato         := Empresa_ArrayOfEmpresaContatoDTO
		//oEmpresa:oWSlstEmpresaEnderecoCobranca := Empresa_ArrayOfEmpresaEnderecoDTO
	/*oEmpresa:oWSlstEmpresaEnderecoCobranca  := Empresa_ArrayOfEmpresaEnderecoDTO():New()
	oEnd := Empresa_EmpresaEnderecoDTO():New()
	oEnd:nbFlPrincipal       := 0
	oEnd:nnCdEmpresaEndereco := 
	oEnd:nnCdEndereco        :=
	oEnd:csCdEstado          :=
	oEnd:csCdPais            := 
	aAdd(oEmpresa:oWSlstEmpresaEnderecoCobranca:oWSEmpresaEnderecoDTO, oEnd:Clone())*/
	//oEmpresa:oWSlstEmpresaEnderecoEntrega       := Empresa_ArrayOfEmpresaEnderecoDTO
	//oEmpresa:oWSlstEmpresaEnderecoFaturamento   := Empresa_ArrayOfEmpresaEnderecoDTO
	//oEmpresa:oWSlstEmpresaEnderecoInstitucional := Empresa_ArrayOfEmpresaEnderecoDTO

	aAdd(oWsEmpresa:oWSlstEmpresa:oWSEmpresaDTO, oEmpresa:Clone())

	If oWsEmpresa:ProcessarEmpresa()
		fWsLogRet( oWsEmpresa:OWSProcessarEmpresaRESULT:OWSLSTWBTLOGDTO:OWSWBTLOGDTO, oLog)
		nProc++
	Else
		fSoapFault(oLog)
	EndIf
	
	fFimLog("Empresa - " + cValToChar(nProc) + ' processado - ' + Time() )
	
	End Sequence
	ErrorBlock(oError)
Return

/*/{Protheus.doc} nCategoria
//Efetua a integra??o das categorias
@author fabricio.reche
@since 07/08/2019
@version 1.0
@param oProcess, object, Objeto de processamento tNewProcess
@type function
/*/
Static Function nCategoria(oProcess)
	Local _cAlias:= GetNextAlias()
	Local cQuery := ""
	Local cCod   := ''
	Local oWsCtg := WSParCategoria():New()
	Local oCateg := Nil  
	Local nProc  := 0
	Local oLog   := FwParLog():New("PAR001", "ProcessarCategoriaProduto")
	Local aReg   := {}
	//Local oError := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'SBM', @oLog, @cCod)}) //Manoel - 108913 (16/05/2022)
	Local oError := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'ZZF', @oLog, @cCod)})

	Begin Sequence
	fIniLog("Categorias")
	                
 	SetRegua2(oProcess, 0)
 	IncRegua2(oProcess, "Buscando Categorias")
    // Manoel - 108913 (16/05/2022)
 	//cQuery := " select R_E_C_N_O_ REG, BM_GRUPO, BM_DESC "
 	//cQuery += " from  " + RetSqlTab("SBM")
	//cQuery += " where D_E_L_E_T_ = ' ' "
	//cQuery += "   and BM_XINTPA > '1' "
	//cQuery += "   and BM_XINTPA < '5' "

	cQuery := " select R_E_C_N_O_ REG, ZZF_CODIGO, ZZF_DESCRI "
 	cQuery += " from  " + RetSqlTab("ZZF")
	cQuery += " where D_E_L_E_T_ = ' ' "
	cQuery += " and ZZF_XINTPA > '1' " //Pendente criação do campo na tabela ZZF
	cQuery += " and ZZF_XINTPA < '5' " //Pendente criação do campo na tabela ZZF

	OPENSQL(_cAlias, cQuery)
                      
	SetRegua2(oProcess,  (_cAlias)->( LastRec() ) )
                                                      
 	while (_cAlias)->( ! EoF() )
 	
 		/* aFiliais */ 
		 // Manoel - 108913 (16/05/2022)
		cCod := (_cAlias)->BM_GRUPO
		IncRegua2(oProcess, "Processando " + (_cAlias)->BM_GRUPO)
 		//cCod := (_cAlias)->ZZF_CODIGO
 		//IncRegua2(oProcess, "Processando " + (_cAlias)->ZZF_CODIGO)

		oCateg:= Categoria_CategoriaDTO():New()
		// Manoel - 108913 (16/05/2022)
		oCateg:csCdClasse := (_cAlias)->BM_GRUPO
		oCateg:csDsClasse := (_cAlias)->BM_DESC
		//oCateg:csCdClasse := (_cAlias)->ZZF_CODIGO
		//oCateg:csDsClasse := (_cAlias)->ZZF_DESCRI
		//oCateg:csCdEmpresa:= SM0->M0_CGC

		If oWsCtg:oWSlstCategoria == Nil .Or. Empty(oWsCtg:oWSlstCategoria)
			oWsCtg:oWSlstCategoria := Categoria_ARRAYOFCATEGORIADTO():New()
		EndIf

		aAdd(aReg, (_cAlias)->REG)
		aAdd(oWsCtg:oWSlstCategoria:oWSParCategoriaDTO, oCateg:Clone())

		(_cAlias)->( DbSkip() )

	endDo
 
 	CLOSESQL(_cAlias)
 
	If !Empty(oWsCtg:oWSlstCategoria:oWSParCategoriaDTO)
 		//faz a chamada do m?todo de integra??o de bancos
	 	If oWsCtg:ProcessarCategoriaProduto()
			//registra o retorno de processar moeda
			// Manoel - 108913 - (16/05/2022)
			//fWsLogRet( oWsCtg:oWSProcessarCategoriaProdutoResult:oWSlstWbtLogDTO:oWSWbtLogDTO, oLog, "SBM", aReg, @nProc )	
			fWsLogRet( oWsCtg:oWSProcessarCategoriaProdutoResult:oWSlstWbtLogDTO:oWSWbtLogDTO, oLog, "ZZF", aReg, @nProc )	
		Else
			fSoapFault(oLog)
	 	EndIf
	EndIf
	
 	fFimLog("Categorias - " + cValToChar(nProc) + ' processados - ' + Time() )
 	End Sequence
	ErrorBlock(oError)
Return nProc


/*/{Protheus.doc} nMoeda
//Efetua a integra??o de moedas
@author Administrator
@since 06/08/2018
@version 1.0               
@param oProcess, object, Objeto de processamento da tNewProcess
@type function
/*/
Static Function nMoeda(oProcess)                               
	Local oWsMoeda 	 := WSMoeda():New()
	Local oMoeda 	 := Nil                    
	Local cQuery 	 := ""                               
	Local cDescMoeda := ""                    
	Local cSigMoeda  := "" 
	Local nProc 	 := 0
	Local nX         := 0
	Local oLog 		 := FwParLog():New("PAR001", "ProcessarMoeda")
	Local aReg 		 := {}
	Local oError     := ErrorBlock({|e| fErrorPar(e:Description, 'CTO', @oLog, @cDescMoeda)})

	Begin Sequence
	fIniLog("Moedas")
	                
 	SetRegua2(oProcess, 0)
 	IncRegua2(oProcess, "Buscando as moedas")
 	        
 	For nX := 1 To 6
 		cDescMoeda := m_vMoeda(nX)
 		cSigMoeda  := M_VSIMB(nX)
 		IncRegua2(oProcess, "Registrando moeda " + cDescMoeda)   
 		
 		If !Empty(cDescMoeda)
			oMoeda			 := Moeda_MoedaDTO():New()
			oMoeda:cScdMoeda := cValToChar(nX)
			oMoeda:cSdsMoeda := AllTrim(cDescMoeda)
			oMoeda:cSsgMoeda := AllTrim(cSigMoeda)
		
			AADD(oWsMoeda:oWsLstMoeda:oWsMoedaDTO, oMoeda:Clone())
		EndIf
	                           
	Next nX
	
	If !Empty(oWsMoeda:oWsLstMoeda:oWsMoedaDTO)
		//faz a chamada da fun??o do web service de moedas
		If oWsMoeda:ProcessarMoeda()
			//registra o retorno de processar moeda
			fWsLogRet( oWsMoeda:OWSPROCESSARMOEDARESULT:OWSLSTWBTLOGDTO:OWSWBTLOGDTO, oLog, "", aReg, @nProc )	
		Else
			fSoapFault(oLog)
		EndIf
		PutMv("MV_XPARMOE", 2) //2=N?o
	EndIf
	                     
	fFimLog("Moedas - " + cValToChar(nProc) + ' processados - ' + Time() )
	End Sequence
	ErrorBlock(oError)
Return nProc


/*/{Protheus.doc} nMoedaCota
//Efetua a integra??o de cota??o de moedas
@author Administrator
@since 14/08/2018
@version 1.0               
@param oProcess, object, Objeto de processamento da tNewProcess
@type function
/*/
Static Function nMoedaCota(oProcess)                               
	Local oWsMoedaCota := WSMoedaCotacao():New()
	Local cAlias       := GetNextAlias()  
	Local oMoeda 	   := Nil                    
	Local cQuery 	   := ""                               
	Local cDescMoeda   := ""                    
	Local cCampo       := "" 
	Local nProc 	   := 0
	Local nX           := 0
	Local oLog 		   := FwParLog():New("PAR001", "ProcessarMoedaCotacao")
	Local aReg 		   := {}
	Local oError       := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'SM2', @oLog, @cDescMoeda)})

	Begin Sequence
	fIniLog("Cotacao Moeda")
	                
 	SetRegua2(oProcess, 0)
 	IncRegua2(oProcess, "Buscando as moedas")
 	//M2_DATA, M2_MOEDA1, M2_MOEDA2, M2_MOEDA3, M2_MOEDA4, M2_MOEDA5 
 	cQuery := " select R_E_C_N_O_ REG, M2_DATA, M2_MOEDA1, M2_MOEDA2, M2_MOEDA3, M2_MOEDA4, M2_MOEDA5, M2_MOEDA6 "
	cQuery += " from  " + RETSQLNAME("SM2") 
	cQuery += " where D_E_L_E_T_ = ' ' "
	cQuery += "   and M2_XINTPA  > '1' "
	cQuery += "   and M2_XINTPA  < '5' "

	//alert(RETSQLNAME('SM2') + ' _ ' + RetSqlTab("SM2") )
	OPENSQL(cAlias, cQuery)
	//alert(cQuery)
	//SetRegua2(oProcess,  (cAlias)->( LastRec() ) )
	DbSelectArea(cAlias)
 	while (cAlias)->( ! EoF() )
 		
 		IncRegua2(oProcess, "Registrando moeda " + cDescMoeda)   
 		
 		For nX := 2 To 6
 			cDescMoeda       := m_vMoeda(nX)
 			cCampo           := 'M2_MOEDA' + cValToChar(nX)
 			//alert(cvaltochar((cAlias)->M2_DATA))
			oMoeda			 := MoedaCotacao_MoedaCotacaoDTO():New()			
			oMoeda:ndVlMoedaCotacao := 1 / (cAlias)->&(cCampo)
			oMoeda:csCdMoedaDestino := cValToChar(nX)
			oMoeda:csCdMoedaOrigem  := '1'
			oMoeda:ctDtMoedaCotacao := FwTimeStamp(3, SToD((cAlias)->M2_DATA), '00:00:00' )
		
			AADD(oWsMoedaCota:oWSlstMoedaCotacao:oWSMoedaCotacaoDTO, oMoeda:Clone())
			
			AADD(aReg, (cAlias)->REG)
		Next nX		
		
	    (cAlias)->( DbSkip() )
	EndDo
	
	If !Empty(oWsMoedaCota:oWSlstMoedaCotacao:oWSMoedaCotacaoDTO)
		//faz a chamada da fun??o do web service de moedas
		If oWsMoedaCota:ProcessarMoedaCotacao()
			//registra o retorno de processar moeda
			fWsLogRet( oWsMoedaCota:oWSProcessarMoedaCotacaoResult:oWSlstWbtLogDTO:oWSWbtLogDTO, oLog, "SM2", aReg, @nProc )	
		Else
			fSoapFault(oLog)
		EndIf
	EndIf
	                     
	fFimLog("Cotacao Moeda - " + cValToChar(nProc) + ' processados - ' + Time() )
	End Sequence
	ErrorBlock(oError)
Return nProc


/*/{Protheus.doc} nUsuario
//Efetua a integra??o de Usu?rio
@author fabricio.reche
@since 07/08/2019
@version 1.0               
@param oProcess, object, Objeto de processamento da tNewProcess
@type function
/*/
Static Function nUsuario(oProcess)                               
	Local oWsUsu   := WSParUsuario():New()
	Local oLog     := FwParLog():New("PAR001", "ProcessarUsuario")
	Local oUsuar   := Nil
	Local oGrupo   := Nil 
	Local oEmp     := Nil
	Local _cAlias  := GetNextAlias()
	Local cQuery   := ''            
	Local cCod     := ''
	Local nProc    := 0
	Local nX       := 0
	Local aReg     := {}
	Local oError   := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'ZUP', @oLog, @cCod)})
	
	Begin Sequence
	fIniLog("Usuario")
	                
 	SetRegua2(oProcess, 0)
 	IncRegua2(oProcess, "Buscando Usuarios")
 	
 	//Par?metro Integra Usu?rio Paradigma
 	If GetMv("MV_XPARUSU") <> 2
 		U_ExecUsu()
 	EndIf

//	cQuery += " ISNULL(CONVERT(VARCHAR(2047), CONVERT(VARBINARY(2047), ZUP_EMPFIL)),'') AS ZUP_EMPFIL "
 	
	cQuery := " select R_E_C_N_O_ REG, ZUP_NOMRED, ZUP_CODUSU, ZUP_NOMCOM, ZUP_BLOQUE, ZUP_EMAIL, ZUP_RAMAL, ZUP_GRUPOS, ZUP_PERFIL, '0101' AS ZUP_EMPFIL"
	cQuery += " from  " + RetSqlTab("ZUP")
	cQuery += " where " + RetSqlCond("ZUP")
	cQuery += " and ZUP_XINTPA > '1' "
	cQuery += " and ZUP_XINTPA < '5' "
 
 	OPENSQL(_cAlias, cQuery)
 	
 	//ALERT(' -> ' + CVALTOCHAR((_cAlias)->( ! EoF() )) + '  -  ' + cQuery )
    
    If (_cAlias)->( ! EoF() )
    	SetRegua2(oProcess,  (_cAlias)->( LastRec() ) )
    EndIf
 	        
 	while (_cAlias)->( ! EoF() ) 
 		cCod := AllTrim((_cAlias)->ZUP_NOMRED)
 		IncRegua2(oProcess, "Registrando Usuario " + (_cAlias)->ZUP_CODUSU)   
 		
 		aFiliais := {}
		oUsuar   := Usuario_UsuarioDTO():New()
		
		oUsuar:csCdUsuario 			:= AllTrim((_cAlias)->ZUP_NOMRED)
		oUsuar:csNmUsuario 			:= AllTrim((_cAlias)->ZUP_NOMCOM)
		oUsuar:nnCdSituacao 		:= IIf((_cAlias)->ZUP_BLOQUE == 'F', 1, 2) //1 ? Ativo  2 ? Inativo
		//oUsuar:csCdDepartamento 	:= AllTrim((_cAlias)->ZUP_DEPART)
		oUsuar:csDsEmailContato 	:= AllTrim((_cAlias)->ZUP_EMAIL)
		If !Empty((_cAlias)->ZUP_RAMAL)
			oUsuar:csNrTelefone 	:= AllTrim((_cAlias)->ZUP_RAMAL)
		EndIf
		oUsuar:csCdEmpresa 			:= FWSM0Util():GetSM0Data(cEmpAnt,cFilAnt,{'M0_CGC'})[1][2] //SM0->M0_CGC 
		aGrupos						:= Separa((_cAlias)->ZUP_GRUPOS, ';', .F.)
		aPerfil  					:= Separa((_cAlias)->ZUP_PERFIL, ';', .F.)
		If AllTrim((_cAlias)->ZUP_EMPFIL) == '@@@@'
			//aAdd(aFiliais, '0305')
		Else
			aFilAux := Separa((_cAlias)->ZUP_EMPFIL, ';', .F.)
			For nX := 1 To Len(aFilAux)				
				aAdd(aFiliais, cGetCgcEmp(aFilAux[nX]))
			Next nX
		EndIf
		
		oUsuar:oWSlstIdPerfil   := Usuario_ArrayOfint():New()
		For nX := 1 To Len(aPerfil)				
			//1 ? Administrador, 2 ? Comprador, 3 ? Vendedor, 4 ? Requisitante
			aAdd(oUsuar:oWSlstIdPerfil:nint, Val(aPerfil[nX]))
		Next nX
		
		If !Empty(aGrupos)
			oUsuar:oWSlstGrupoUsuario	:= Usuario_ArrayOfGrupoUsuarioDTO():New()
			For nX := 1 To Len(aGrupos)
				oGrupo 			 := Usuario_GrupoUsuarioDTO():New()
				oGrupo:nnCdGrupo := Val(aGrupos[nX])
				aAdd(oUsuar:oWSlstGrupoUsuario:oWSGrupoUsuarioDTO, oGrupo:Clone())
			Next nX
		EndIf
		
		If !Empty(aFiliais) //!('@@@@' $ (_cAlias)->ZUP_EMPFIL)
		    oUsuar:oWSlstUsuarioEmpresa := Usuario_ArrayOfUsuarioEmpresaDTO():New()
		    For nX := 1 To Len(aFiliais)
			    oEmp 			 := Usuario_UsuarioEmpresaDTO():New()
			    oEmp:csCdEmpresa := aFiliais[nX]
				aAdd(oUsuar:oWSlstUsuarioEmpresa:oWSParUsuarioEmpresaDTO, oEmp:Clone())
			Next nX
	    EndIf

		aAdd(aReg, (_cAlias)->REG)
		aAdd(oWsUsu:oWSlstUsuario:oWSParUsuarioDTO, oUsuar:Clone())

		(_cAlias)->(DbSkip())
	EndDo
	
	CLOSESQL(_cAlias)
	
	If !Empty(oWsUsu:oWSlstUsuario:oWSParUsuarioDTO)
		If oWsUsu:ProcessarUsuario()
			//registra o retorno de processar usuario
			fWsLogRet( oWsUsu:oWSProcessarUsuarioResult:oWSlstWbtLogDTO:oWSWbtLogDTO, oLog, "ZUP", aReg, @nProc )	
		Else
			fSoapFault(oLog)
		EndIf
	EndIf
	                     
	fFimLog("Usuario - " + cValToChar(nProc) + ' processados - ' + Time())
	End Sequence
	ErrorBlock(oError)
Return nProc


/*/{Protheus.doc} nBanco
//Efetua a integra??o dos bancos
@author fabri
@since 07/08/2019
@version 1.0
@param oProcess, object, Objeto de processamento da tNewProcess
@type function
/*/
Static Function nBanco(oProcess)
	Local oWsBanco := Nil
	Local oBanco   := Nil                    
	Local cQuery   := ""
	Local cCod     := ''
	Local _cAlias  := GetNextAlias()  
	Local nProc    := 0
	Local oLog     := FwParLog():New("PAR001", "ProcessarBanco")
	Local aReg     := {}
	Local oError   := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'SA6', @oLog, @cCod)})

	Begin Sequence
	fIniLog("Bancos")               

 	SetRegua2(oProcess, 0)
 	IncRegua2(oProcess, "Buscando os bancos")

	//cQuery += " select max(R_E_C_N_O_) REG, A6_COD, A6_NOME "
	cQuery += " select R_E_C_N_O_ REG, A6_COD, A6_NOME "
	cQuery += " from " + RetSqlTab("SA6")
	cQuery += " where D_E_L_E_T_ = ' ' "
	cQuery += "   and A6_XINTPA > '1' "
	cQuery += "   and A6_XINTPA < '5' "
	//cQuery += "   GROUP BY A6_COD, A6_NOME  "
	//cQuery += " order by A6_COD, A6_NOME "

	OPENSQL(_cAlias, cQuery)

	SetRegua2(oProcess,  (_cAlias)->( LastRec() ) )
	
	oWsBanco := WSParBanco():New()
	
 	while (_cAlias)->( ! EoF() )
 		cCod := AllTrim((_cAlias)->A6_COD)
 		IncRegua2(oProcess, "Processando " + (_cAlias)->A6_COD)
		oBanco   := Banco_BancoDTO():New()
		oBanco:cScdBanco := AllTrim((_cAlias)->A6_COD)
		oBanco:cSnmBanco := AllTrim((_cAlias)->A6_NOME)
		oBanco:csCdPais  := 'BR'

		oBanco:oWSlstAgenciaDTO := Banco_ArrayOfAgenciaBancoDTO():NEW()

		aAdd(aReg, (_cAlias)->REG)

		aAdd(oWsBanco:oWSlstBanco:oWSParBancoDTO, oBanco:Clone())

		//oLog := FwParLog():New("PAR001", "ProcessarBanco")
	 	(_cAlias)->( DbSkip() )
	EndDo
 	CLOSESQL(_cAlias)
 	
 	If !Empty(oWsBanco:oWSlstBanco:oWSParBancoDTO)
 		//faz a chamada do m?todo de integra??o de bancos
	 	If oWsBanco:ProcessarBanco()
			//registra o retorno de processar
			fWsLogRet( oWsBanco:oWSProcessarBancoResult:oWSlstWbtLogDTO:oWSWbtLogDTO, oLog, "SA6", @aReg, @nProc )
		Else
			fSoapFault(oLog)
	 	EndIf
 	EndIf
 	
	fFimLog("Bancos - " + cValToChar(nProc) + ' processados - ' + Time() )
	End Sequence
	ErrorBlock(oError)

Return nProc

/*/{Protheus.doc} nUnidMed
//Efetua a integra??o das unidades de medidas
@author fabricio.reche
@since 07/08/2019
@version 1.0
@param oProcess, object, Objeto de processamento tNewProcess
@type function
/*/
Static Function nUnidMed(oProcess)
	Local _cAlias:= GetNextAlias()
	Local cQuery := ""
	Local cCod   := ''
	Local oWsUm  := WSUnidadeMedida():New()  
	Local nProc  := 0
	Local oLog   := FwParLog():New("PAR001", "ProcessarUnidadeMedida")
	Local aReg   := {}
	Local oUM    := Nil
	Local oError := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'SAH', @oLog, @cCod)})

	Begin Sequence
	fIniLog("Unidades Medidas")               
	                
 	SetRegua2(oProcess, 0)
 	IncRegua2(oProcess, "Buscando Unidades de Medidas")

 	cQuery += " select R_E_C_N_O_ REG, AH_UNIMED, AH_DESCPO "
 	cQuery += " from " + RetSqlTab("SAH")
 	cQuery += " where " + RetSqlCond("SAH")
 	cQuery += "   and AH_XINTPA > '1' "
	cQuery += "   and AH_XINTPA < '5' "
 	cQuery += " order by AH_UNIMED, AH_DESCPO "

	OPENSQL(_cAlias, cQuery)
                      
	SetRegua2(oProcess,  (_cAlias)->( LastRec() ) )
                                                      
 	while (_cAlias)->( ! EoF() )
 		cCod := (_cAlias)->AH_UNIMED
 		IncRegua2(oProcess, "Processando " + (_cAlias)->AH_UNIMED)
 	
		oUM := UnidadeMedida_UnidadeMedidaDTO():New()
		oUM:csCdUnidadeMedida := (_cAlias)->AH_UNIMED
		oUM:csSgUnidadeMedida := (_cAlias)->AH_UNIMED
		oUM:csDsUnidadeMedida := (_cAlias)->AH_DESCPO

		aAdd(aReg, (_cAlias)->REG)
		aAdd(oWsUm:oWSlstUnidadeMedida:oWSUnidadeMedidaDTO, oUM:Clone())

		(_cAlias)->( DbSkip() )
	
	endDo
 	
 	CLOSESQL(_cAlias)
 	
 	If !Empty(oWsUm:oWSlstUnidadeMedida:oWSUnidadeMedidaDTO)
 		//faz a chamada do m?todo de integra??o de bancos
	 	If oWsUm:ProcessarUnidadeMedida()
			//registra o retorno de processar moeda
			fWsLogRet( oWsUm:oWSProcessarUnidadeMedidaResult:oWSlstWbtLogDTO:oWSWbtLogDTO, oLog, "SAH", aReg, @nProc )	
		Else
			fSoapFault(oLog)
	 	EndIf
 	EndIf
 	
 	fFimLog("Unidades Medidas - " + cValToChar(nProc) + ' processados - ' + Time() )
	End Sequence
	ErrorBlock(oError)
Return nProc

/*/{Protheus.doc} nCondPgto
//Efetua a integra??o das condi??es de pagamento
@author fabricio.reche
@since 07/08/2019
@version 1.0
@param oProcess, object, Objeto de processamento tNewProcess
@type function
/*/
Static Function nCondPgto(oProcess)
	Local _cAlias:= GetNextAlias()
	Local cQuery := ""
	Local cCod   := ''
	Local oWsCpg := WSCondicaoPagamento():New()
	Local oCndPg := Nil     
	Local nProc  := 0
	Local oLog   := FwParLog():New("PAR001", "ProcessarCondicaoPagamento")
	Local aReg   := {}
	Local oError := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'SE4', @oLog, @cCod)})
    
    Begin Sequence
	fIniLog("Condicoes de Pagamentos")
	                
 	SetRegua2(oProcess, 0)
 	IncRegua2(oProcess, "Condicoes de Pagamentos")

 	cQuery += " select R_E_C_N_O_ REG, E4_CODIGO, E4_DESCRI "
 	cQuery += " from " + RetSqlTab("SE4")
 	cQuery += " where " + RetSqlCond("SE4")
 	cQuery += "   and E4_MSBLQL <> '1' "
 	cQuery += "   and E4_XINTPA  > '1' "
	cQuery += "   and E4_XINTPA  < '5' "

	OPENSQL(_cAlias, cQuery)
                      
	SetRegua2(oProcess,  (_cAlias)->( LastRec() ) )
                                                      
 	while (_cAlias)->( ! EoF() )
 		/* aFiliais */
 		cCod := (_cAlias)->E4_CODIGO
 		IncRegua2(oProcess, "Processando " + (_cAlias)->E4_CODIGO)

		oCndPg:= CondicaoPagamento_CondicaoPagamentoDTO():New()
		oCndPg:csCdCondicaoPagamento := (_cAlias)->E4_CODIGO
		oCndPg:csDsCondicaoPagamento := (_cAlias)->E4_DESCRI
		oCndPg:csCdEmpresa           := FWSM0Util():GetSM0Data(cEmpAnt,cFilAnt,{'M0_CGC'})[1][2] //SM0->M0_CGC

		aAdd(aReg, (_cAlias)->REG)
		aAdd(oWsCpg:oWSlstCondicaoPagamento:oWSCondicaoPagamentoDTO, oCndPg:Clone())

		(_cAlias)->( DbSkip() )
	endDo
 
 	CLOSESQL(_cAlias)
 
	If !Empty(oWsCpg:oWSlstCondicaoPagamento:oWSCondicaoPagamentoDTO)
 		//faz a chamada do m?todo de integra??o
	 	If oWsCpg:ProcessarCondicaoPagamento()
			//registra o retorno de processar
			fWsLogRet( oWsCpg:oWSProcessarCondicaoPagamentoResult:oWSlstWbtLogDTO:oWSWbtLogDTO, oLog, "SE4", aReg, @nProc )	
		Else
			fSoapFault(oLog)
	 	EndIf
	EndIf
 	
 	fFimLog("Condicoes de Pagamentos - " + cValToChar(nProc) + ' processados - ' + Time() )
	End Sequence
	ErrorBlock(oError)
Return nProc
      
/*/{Protheus.doc} nCentroCus
//Efetua a integra??o dos centros de custos
@author fabricio.reche
@since 07/08/2019
@version 1.0
@param oProcess, object, Objeto de processamento tNewProcess
@type function
/*/
Static Function nCentroCus(oProcess)
	Local _cAlias:= GetNextAlias()
	Local cQuery := ""
	Local cCod   := ''
	Local oWsCdC := WSCentroCusto():New()
	Local nProc  := 0
	Local oCdC   := Nil  
	Local oLog   := FwParLog():New("PAR001", "ProcessarCentroCusto")
	Local aReg   := {}
	Local oError := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'CTT', @oLog, @cCod)})
                                               
	Begin Sequence
	fIniLog("Centros de Custos")
	                
 	SetRegua2(oProcess, 0)
 	IncRegua2(oProcess, "Centros de Custos")

 	cQuery += " select R_E_C_N_O_ REG, CTT_CUSTO, CTT_DESC01, CTT_BLOQ, D_E_L_E_T_ DEL "
 	cQuery += " from " + RetSqlTab("CTT")
 	cQuery += " where " + RetSqlCond("CTT")
 	cQuery += "   and CTT_CLASSE = '2' "
 	cQuery += "   and CTT_XINTPA > '1' "
	cQuery += "   and CTT_XINTPA < '5' "

	OPENSQL(_cAlias, cQuery)

	SetRegua2(oProcess,  (_cAlias)->( LastRec() ) )

 	while (_cAlias)->( ! EoF() )
 		/* aFiliais */ 
 		cCod := (_cAlias)->CTT_CUSTO 
 		IncRegua2(oProcess, "Processando " + (_cAlias)->CTT_CUSTO)

		oCdC:= CentroCusto_CentroCustoDTO():New()
		oCdC:nbFlAtivo       := IIf(((_cAlias)->CTT_BLOQ == "1" .Or. !Empty((_cAlias)->DEL)), 0, 1)
		oCdC:csCdEmpresa     := FWSM0Util():GetSM0Data(cEmpAnt,cFilAnt,{'M0_CGC'})[1][2]//SM0->M0_CGC
		oCdC:csCdCentroCusto := AllTrim( (_cAlias)->CTT_CUSTO )
		oCdC:csDsCentroCusto := oCdC:csCdCentroCusto + ' - ' + AllTrim((_cAlias)->CTT_DESC01)

		aAdd(aReg, (_cAlias)->REG)
		aAdd(oWsCdC:oWSlstCentroCusto:oWSCentroCustoDTO, oCdC:Clone())

		(_cAlias)->( DbSkip() )

	endDo
 
 	CLOSESQL(_cAlias)
 
	If !Empty(oWsCdC:oWSlstCentroCusto:oWSCentroCustoDTO)
 		//faz a chamada do m?todo de integra??o
	 	If oWsCdC:ProcessarCentroCusto()
			//registra o retorno de processar
			fWsLogRet( oWsCdC:oWSProcessarCentroCustoResult:oWSlstWbtLogDTO:oWSWbtLogDTO, oLog, "CTT", aReg, @nProc )	
		Else
			fSoapFault(oLog)
	 	EndIf
	EndIf
 	
 	fFimLog("Centros de Custos - " + cValToChar(nProc) + ' processados - ' + Time() )
	End Sequence
	ErrorBlock(oError)
Return nProc


/*/{Protheus.doc} nContaContab
//Efetua a integra??o de Conta Contabil
@author geovani.figueira
@since 06/08/2018
@version 1.0
@param oProcess, object, Objeto de processamento tNewProcess
@type function
/*/
Static Function nContaContab(oProcess)
	Local cAlias 	:= GetNextAlias()
	Local cQuery 	:= ""
	Local cCod      := ''
	Local oWsConta 	:= WSContaContabil():New()
	Local nProc  	:= 0
	Local oConta 	:= Nil  
	Local oLog   	:= FwParLog():New("PAR001", "ProcessarContaContabil")
	Local aReg   	:= {}
	Local oError    := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'CT1', @oLog, @cCod)})
    
    Begin Sequence
	fIniLog("Conta Contabil")
	                
 	SetRegua2(oProcess, 0)
 	IncRegua2(oProcess, "Conta Contabil")

 	cQuery += " select R_E_C_N_O_ REG, CT1_CONTA, CT1_DESC01, CT1_BLOQ, D_E_L_E_T_ DEL  "
 	cQuery += " from " + RetSqlTab("CT1")
 	cQuery += " where D_E_L_E_T_ = ' ' "
 	cQuery += "   and CT1_CLASSE = '2' "
 	cQuery += "   and CT1_XINTPA > '1' "
	cQuery += "   and CT1_XINTPA < '5' "

	OPENSQL(cAlias, cQuery)

	SetRegua2(oProcess,  (cAlias)->( LastRec() ) )

 	while (cAlias)->( ! EoF() )
 		/* aFiliais */ 
 		cCod := (cAlias)->CT1_CONTA
 		IncRegua2(oProcess, "Processando " + (cAlias)->CT1_CONTA)

		oConta:= ContaContabil_ContaContabilDTO():New() 
		oConta:nbFlAtivo       	 := IIf(((cAlias)->CT1_BLOQ == "1" .Or. !Empty((cAlias)->DEL)), 0, 1)
		oConta:csCdContaContabil := AllTrim( (cAlias)->CT1_CONTA )
		oConta:csDsContaContabil := oConta:csCdContaContabil + ' - ' + AllTrim((cAlias)->CT1_DESC01)
		oConta:csCdEmpresa     	 := FWSM0Util():GetSM0Data(cEmpAnt,cFilAnt,{'M0_CGC'})[1][2]//SM0->M0_CGC
		
		aAdd(aReg, (cAlias)->REG)
		aAdd(oWsConta:oWSlstContaContabil:oWSContaContabilDTO, oConta:Clone())

		(cAlias)->( DbSkip() )

	endDo
 
 	CLOSESQL(cAlias)
 
	If !Empty(oWsConta:oWSlstContaContabil:oWSContaContabilDTO)
 		//faz a chamada do m?todo de integra??o
	 	If oWsConta:ProcessarContaContabil()
			//registra o retorno de processar
			fWsLogRet( oWsConta:oWSProcessarContaContabilResult:oWSlstWbtLogDTO:oWSWbtLogDTO, oLog, "CT1", aReg, @nProc )	
		Else
			fSoapFault(oLog)
	 	EndIf
 	EndIf
 	
 	fFimLog("Conta Contabil - " + cValToChar(nProc) + ' processados - ' + Time() )
	End Sequence
	ErrorBlock(oError)
Return nProc


/*/{Protheus.doc} aProdutos
//Efetua a integra??o produtos
@author fabricio.reche
@since 07/08/2019
@version 1.0               
@param oProcess, object, Objeto de processamento da tNewProcess
@Return aReg, lista de recnos processados (reuso na segunda unidade de medida)
@type function
/*/
Static Function aProdutos(oProcess)                               
	Local oWsProduto := WSParProduto():New()
	Local oProduto	 := Nil                    
	Local cQuery 	 := ""
	Local cCod       := ""
	Local _cAlias 	 := GetNextAlias()            
	Local oLog		 := FwParLog():New("PAR001", "ProcessarProduto")
	Local aReg		 := {}
	Local nCM1		 := 0
	Local oError     := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'SB1', @oLog, @cCod)})
    Local nCont      := 0         
    
    Begin Sequence
	fIniLog("Produtos")
                    
 	SetRegua2(oProcess, 0)
 	IncRegua2(oProcess, "Buscando Produtos")
 	
 	cQuery += " select  * "
 	cQuery += " from  " + RetSqlTab("SB1")
 	cQuery += " where B1_FILIAL = " + ValToSQL(xFilial("SB1"))
 	cQuery += "   and B1_XINTPA > '1' "
	cQuery += "   and B1_XINTPA < '5' "
 	cQuery += "   and B1_MSBLQL = '2' "
 
 	OPENSQL(_cAlias, cQuery)

    SetRegua2(oProcess, 500 )
   
	/* aFiliais */ 
	IncRegua2(oProcess, "Registrando produto " + (_cAlias)->B1_COD)   
	
	//nCM1 := POSICIONE('SB2', 1, xFilial('SB2')+(_cAlias)->B1_COD+(_cAlias)->B1_LOCPAD, 'B2_CM1')

 	while Select(_cAlias) <> 0 .And. (_cAlias)->( ! EoF() ) .And. ! Empty((_cAlias)->B1_COD)
                  
        nCont:=nCont+1

 		IncRegua2(oProcess, "Registrando produto " + (_cAlias)->B1_COD)   

 		cCod := (_cAlias)->B1_COD
 		If EncodeUTF8(AllTrim((_cAlias)->B1_DESC), "cp1252") == Nil
 			//if ! IsBlind()
 			//	Alert(' Caracter inv?lido na descri??o do produto ' + AllTrim((_cAlias)->B1_COD))
 			//endIf
 			oLog:Retorno   := 0
			oLog:Origem    := cCod
			oLog:MsgLog    := 'Caracter invalido na descricao do produto ' + AllTrim((_cAlias)->B1_COD)
			oLog:SoapFault := 'Caracter invalido na descricao do produto ' + AllTrim((_cAlias)->B1_COD)
			oLog:Tstamp    := FwTimeStamp(3)		
			oLog:SalvaObj('SB1')
			oLog:novoLog()
 			
 			(_cAlias)->(DbSkip())
 			Loop
 		EndIf
 		
 		//nCM1 := POSICIONE('SB2', 1, xFilial('SB2')+(_cAlias)->B1_COD+(_cAlias)->B1_LOCPAD, 'B2_CM1')
 		oProduto							   :=  Produto_ProdutoDTO():New()
		oProduto:nnSituacaoProduto             :=  Iif((_cAlias)->B1_MSBLQL != '1' .And. Empty((_cAlias)->R_E_C_D_E_L_), 1, 0)
		oProduto:csCdUnidadeMedida             :=  (_cAlias)->B1_UM
		oProduto:csCdEmpresa                   :=  FWSM0Util():GetSM0Data(cEmpAnt,cFilAnt,{'M0_CGC'})[1][2]//SM0->M0_CGC
		oProduto:csCdProduto                   :=  AllTrim((_cAlias)->B1_COD)
		oProduto:csDsProduto                   :=  AllTrim((_cAlias)->B1_DESC)
		oProduto:csDsDetalhe                   :=  AllTrim((_cAlias)->B1_DESC)
		oProduto:csCdClasse                    :=  (_cAlias)->B1_GRUPO
		//cQuery += "   and B1_MSBLQL != '1' "
		//oProduto:ndQtConsumoMedio              :=  0 //2 //nCM1 		// SB2->B2_CM1
		//oProduto:nnCdProdutoTipo               :=  1 //IIf(AllTrim((_cAlias)->B1_TIPO) $ "/SR/SV/", 2, 1)
		//oProduto:ndVlPeso                      :=  0 //(_cAlias)->B1_PESO
		//Alert('ok')
		//oProduto:oWSlstProdutoIdioma           := Produto_ArrayOfProdutoIdiomaDTO
		//oProduto:nnCdGrupoDespesaTipo          := long
		//oProduto:nnCdTipoSituacaoMapDestinacao := int
		//oProduto:oWSoGrupoDespesaTipo          := Produto_GrupoDespesaTipoDetalheDTO
		//oProduto:oWSoUnidadeMedidaDetalhe      := Produto_UnidadeMedidaDetalheDTO
		//oProduto:nsCdProdutoWBC                := long

		aAdd(aReg, (_cAlias)->R_E_C_N_O_)

		aAdd(oWsProduto:oWSlstProduto:oWSParProdutoDTO, oProduto:Clone())

		(_cAlias)->( DbSkip() )
             

     
        If nCont > 999
      
           //msginfo(str(nCont))
           nCont:= 0              
   
           Exit
           
        Endif    

	endDo

	CLOSESQL(_cAlias)

	If !Empty(oWsProduto:oWSlstProduto:oWSParProdutoDTO)
		//faz a chamada da fun??o do web service de moedas

		If oWsProduto:ProcessarProduto()
			//registra o retorno de processar moeda
			fWsLogRet( oWsProduto:OWSProcessarProdutoRESULT:OWSLSTWBTLOGDTO:OWSWBTLOGDTO, oLog, "SB1", @aReg )	

		Else

			fSoapFault(oLog)
			aReg := {}
		EndIf
	EndIf

	fFimLog("Produtos - " + cValToChar(Len(aReg)) + ' processados - ' + Time() )
	End Sequence
	ErrorBlock(oError)
Return aReg


/*/{Protheus.doc} nSegUnidMe
//Efetua a integra??o da segunda unidade de medida (Unidade Convers?o)
@author fabricio.reche
@since 07/08/2019
@version 1.0
@param oProcess, object, Objeto de processamento tNewProcess
@param aReg, array, Lista de Recnos da SB1 j? processados
@type function
/*/
Static Function nSegUnidMe(oProcess, aReg)
	Local aAreas   := SB1->( GetArea() )
	Local cCod     := ""
	Local oWsSegUm := WSProdutoUnidadeConversao():New()
	Local oSegUm   := Nil   
	Local nProc    := 0
	Local oLog     := FwParLog():New("PAR001", "ProcessarProdutoUnidadeConversao")
	Local nX       := 0
	Local nQtd     := 0
	Local aProc    := {}
	Local oError   := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'SB1', @oLog, @cCod)})
	
	Default aReg := {}
    
    Begin Sequence
	fIniLog("Segunda Unidade Medida")
	                
 	SetRegua2(oProcess, 0)
 	IncRegua2(oProcess, "Segunda Unidade Medida") 	
 	SetRegua2(oProcess,  Len(aReg) )
 	
 	for nX := 1 to Len(aReg)
 
 		//posiciona na SB1 para os c?lculos da fun??o ConvUM
		SB1->( DbGoTo( aReg[nX] ) )
	    cCod := SB1->B1_COD
	    nQtd := ConvUm(SB1->B1_COD, 1, 0, 2)
		//caso nao tenha segunda unidade de medida, nao precisa integrar                                              
		If Empty(SB1->B1_SEGUM) .Or. SB1->B1_SEGUM == SB1->B1_UM .Or. nQtd == 0
			Loop
		EndIf
		
		aAdd(aProc, aReg[nX])
		IncRegua2(oProcess, "Processando " + SB1->B1_SEGUM)
	
		oSegUm := ProdutoUnidadeConversao_ProdutoUnidadeConversaoDTO():New()
		oSegUm:csCdProduto              := AllTrim(SB1->B1_COD)
		oSegUm:ndQtConversao            := nQtd
		oSegUm:csCdUnidadeMedidaOrigem  := SB1->B1_UM
		oSegUm:csCdUnidadeMedidaDestino := SB1->B1_SEGUM
			
		aAdd(oWsSegUm:oWSlstProdutoUnidadeConversao:oWSProdutoUnidadeConversaoDTO, oSegUm:Clone())

 	next nX
 
 	SB1->( RestArea( aAreas ) )
 
	If !Empty(oWsSegUm:oWSlstProdutoUnidadeConversao:oWSProdutoUnidadeConversaoDTO)
 		//faz a chamada do m?todo de integra??o
	 	If oWsSegUm:ProcessarProdutoUnidadeConversao()
			//registra o retorno de processar
			fWsLogRet( oWsSegUm:oWSProcessarProdutoUnidadeConversaoResult:oWSlstWbtLogDTO:oWSWbtLogDTO, oLog, "SB1", aProc, @nProc )	
		Else
			fSoapFault(oLog)
	 	EndIf
 	EndIf
 	
 	fFimLog("Segunda Unidade Medida - " + cValToChar(nProc) + ' processados - ' + Time())
 	End Sequence
	ErrorBlock(oError)
Return nProc


/*/{Protheus.doc} aProdutos
//Efetua a integra??o produtos
@author fabricio.reche
@since 07/08/2019
@version 1.0               
@param oProcess, object, Objeto de processamento da tNewProcess
@Return aReg, lista de recnos processados (reuso na segunda unidade de medida)
@type function
/*/
Static Function nGrupComp(oProcess)                               
	Local oWsGrpComp := WSGrupoCompra():New()
	Local oGrpComp	 := Nil
	Local oClasse	 := Nil
	Local cQuery 	 := ""
	Local cCod       := ""
	Local _cAlias 	 := GetNextAlias()            
	Local oLog		 := FwParLog():New("PAR001", "ProcessarGrupoCompra")
	Local aReg		 := {}
	Local nProc		 := 0
	Local oError     := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'PAO', @oLog, @cCod)})
    
    Begin Sequence
	fIniLog("GrupoCompra")
                    
 	SetRegua2(oProcess, 0)
 	IncRegua2(oProcess, "Buscando Grupo Compras")
 	
 	cQuery := " select  * "
 	cQuery += " from  " + RetSqlTab("PAO")
 	cQuery += " where D_E_L_E_T_ = ' ' "
 	cQuery += "   and PAO_XINTPA > '1' "
	cQuery += "   and PAO_XINTPA < '5' "
 	cQuery += "   and PAO_ATIVO  = '1' "
 
 	OPENSQL(_cAlias, cQuery)
 	DbSelectArea(_cAlias)
    SetRegua2(oProcess, (_cAlias)->( LastRec() ) )
    
 	While Select(_cAlias) <> 0 .And. (_cAlias)->( ! EoF() )

 		IncRegua2(oProcess, "Registrando Grupo Compra " + (_cAlias)->PAO_CODCOM)   

 		cCod := (_cAlias)->PAO_CODCOM
 		aReg := {}
 		
 		oGrpComp := GrupoCompra_GrupoCompraDTO():New()
		
		oGrpComp:csCdGrupoCompra	:= AllTrim((_cAlias)->PAO_CODCOM)
		oGrpComp:csDsGrupoCompra	:= AllTrim((_cAlias)->PAO_NOMCOM)
		//oGrpComp:csSgGrupoCompra	:=
		oGrpComp:oWSlstCategoria	:= GrupoCompra_ArrayOfClasseDTO():New()

		While (_cAlias)->( ! EoF() ) .And. AllTrim((_cAlias)->PAO_CODCOM) == AllTrim(oGrpComp:csCdGrupoCompra)
		                       
			IncRegua2(oProcess, "Processando Grupo Compra " + (_cAlias)->PAO_CODCOM)
			
			oClasse := GrupoCompra_ClasseDTO():New()
			oClasse:csCdClasse := AllTrim((_cAlias)->PAO_CODGRP)
			
			aAdd(aReg, (_cAlias)->R_E_C_N_O_)
			
			aAdd(oGrpComp:oWSlstCategoria:oWSClasseDTO, oClasse:Clone())
		                  
			(_cAlias)->( DbSkip() )
		EndDo                     
		
		aAdd(oWsGrpComp:oWSlstGrupoCompra:oWSGrupoCompraDTO, oGrpComp:Clone())
		
		If !Empty(oWsGrpComp:oWSlstGrupoCompra:oWSGrupoCompraDTO)
		 	If oWsGrpComp:ProcessarGrupoCompra()
				fWsLogRet( oWsGrpComp:oWSProcessarGrupoCompraResult:oWSlstWbtLogDTO:oWSWbtLogDTO, oLog, "PAO", aReg, @nProc )	
			Else
				fSoapFault(oLog)
		 	EndIf
	 	EndIf
	 	oLog:novoLog()		
	EndDo

	CLOSESQL(_cAlias)

	fFimLog("Grupo Compra - " + cValToChar(nProc) + ' processados - ' + Time() )
	End Sequence
	ErrorBlock(oError)
Return nProc

/*/{Protheus.doc} nRetFornec
//Integra os Retorno de Fornecedor da paradigma
@author geovani.figueira
@since 06/08/2018
@version 1.0
@param oProcess, object, objeto tNewProcess
@type function
/*/
Static Function nRetFornec(oProcess)
	Local oLog    := FwParLog():New("PAR001", "RetornarEmpresaVencedoraSemDePara")
	Local oWsEmp  := WSEmpresa():New()
	Local oFornec := Nil
	Local aFor    := {}
	Local nProc	  := 0
	Local nX      := 0
	Local cReg    := ''
	Local cCodMun := ''
	Local cQuery  := ''
	Local _cAlias := GetNextAlias()
	Local oError  := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'SA2', @oLog, @cReg)})
	
	Private lMsErroAuto := .F.
	
	Begin Sequence
	fIniLog("Retorno de Fornecedores")
	
	If oWsEmp:RetornarEmpresaVencedoraSemDePara()
		//oWsEmp:oWSRetornarEmpresaVencedoraSemDeParaResult:oWSEmpresaDTO, .T., oLog, @nProc	
		oFornec := oWsEmp:oWSRetornarEmpresaVencedoraSemDeParaResult:oWSEmpresaDTO
		
		For nX := 1 To Len(oFornec)
			cReg := cValToChar(oFornec[nX]:nnCdEmpresaWbc)
			lMsErroAuto := .F.
			aFor := {}
			
			dbSelectArea("SA2")
			dbSetOrder(3)  //A2_FILIAL+A2_CGC
			If dbSeek(xFilial('SA2')+PADR(oFornec[nX]:csNrCnpj,Len(SA2->A2_CGC))) .And. cReg $ SA2->A2_XEMPWBC
				conout('Fornecedor ' + cReg + ' j? cadastrado.')
				LOOP
			EndIf
			
			cCodigo := IIf(Empty(oFornec[nX]:csNrCnpj), '000100', Substr(oFornec[nX]:csNrCnpj,1,6))
			dbSetOrder(1)  //A2_FILIAL+A2_COD+A2_LOJA
			While dbSeek(xFilial('SA2')+cCodigo+'01')
				cCodigo := Soma1(cCodigo)
			EndDo
			
			nProc++
			
			cCodMun := POSICIONE('CC2', 4, xFilial('CC2')+oFornec[nX]:csSgEstado+PADR(oFornec[nX]:csNmCidade,tamsx3("CC2_MUN")[1]), 'CC2_CODMUN')
				
			cQuery := " SELECT YA_CODGI, CCH_CODIGO "
			cQuery += " FROM  " + RetSqlTab("SYA") + ", " + RetSqlTab("CCH")
			cQuery += " WHERE " + RetSqlCond("SYA")
			cQuery += " AND " + RetSqlCond("CCH")
			cQuery += " AND YA_PAISDUE = '" + oFornec[nX]:csSgPais + "' "
			cQuery += " AND YA_DESCR = CCH_PAIS "

			OPENSQL(_cAlias, cQuery)
			If !(_cAlias)->( EOF() )
				aAdd(aFor, {"A2_PAIS"   , (_cAlias)->YA_CODGI                         ,})
				aAdd(aFor, {"A2_CODPAIS", (_cAlias)->CCH_CODIGO                       ,})
			EndIf
			CLOSESQL(_cAlias)
			
			aAdd(aFor, {"A2_COD"    , cCodigo					                     ,})
			aAdd(aFor, {"A2_LOJA"   , '01'						                     ,})
			aAdd(aFor, {"A2_NOME"   , oFornec[nX]:csNmEmpresa                        ,})
			aAdd(aFor, {"A2_NREDUZ" , Substr(oFornec[nX]:csNmFantasia, 1, 20)        ,})
			aAdd(aFor, {"A2_TIPO"   , IIf(oFornec[nX]:nnIdTipoPessoa == 1, "F", "J") ,})
			aAdd(aFor, {"A2_CGC"    , oFornec[nX]:csNrCnpj                           ,})
			aAdd(aFor, {"A2_INSCR"  , IIf(Empty(oFornec[nX]:csNrInscricaoEstadual) , 'ISENTO', oFornec[nX]:csNrInscricaoEstadual)  ,})
			aAdd(aFor, {"A2_INSCRM" , IIf(Empty(oFornec[nX]:csNrInscricaoMunicipal), 'ISENTO', oFornec[nX]:csNrInscricaoMunicipal) ,})
			If !Empty(oFornec[nX]:csCdCnae)
				aAdd(aFor, {"A2_CNAE"   , oFornec[nX]:csCdCnae                       ,})
			EndIf
			aAdd(aFor, {"A2_DTINIV" , StoD(Left(StrTran(oFornec[nX]:ctDtInicioAtividade, "-", ""), 8)) ,})
			aAdd(aFor, {"A2_TEL"    , oFornec[nX]:csNrTelefone                       ,})
			aAdd(aFor, {"A2_FAX"    , oFornec[nX]:csNrFax                            ,})
			aAdd(aFor, {"A2_CONTATO", oFornec[nX]:csNmContato                        ,})
			aAdd(aFor, {"A2_CEP"    , StrTran(oFornec[nX]:csDsCep, "-", "" )         ,})
			aAdd(aFor, {"A2_XEMAIL"  , oFornec[nX]:csDsEmailContato                   ,})
			aAdd(aFor, {"A2_END"    , oFornec[nX]:csDsEndereco                       ,})
			aAdd(aFor, {"A2_COMPLEM", oFornec[nX]:csDsEnderecoComplemento            ,})
			aAdd(aFor, {"A2_BAIRRO" , oFornec[nX]:csNmBairro                         ,})
			aAdd(aFor, {"A2_EST"    , oFornec[nX]:csSgEstado                         ,})
			aAdd(aFor, {"A2_MUN"    , oFornec[nX]:csNmCidade                         ,})
			aAdd(aFor, {"A2_COD_MUN", cCodMun                                        ,})			
			aAdd(aFor, {"A2_TIPORUR", IIf(oFornec[nX]:nnIdTipoPessoa == 1, "F", "J") ,})
			aAdd(aFor, {"A2_MSBLQL" , '2'                                            ,})
			//aAdd(aFor, {"A2_NATUREZ", Iif(Empty(oFornec[nX]:csCdNaturezaJuridica), '216011', oFornec[nX]:csCdNaturezaJuridica)     ,})
			//aAdd(aFor, {"A2_CONTA"  , '2010201002'      							 ,}) //IIf(oFornec[nX]:csSgPais == 'BR', '221101001', '211101002') ,})
			aAdd(aFor, {"A2_XEMPWBC", cValToChar(oFornec[nX]:nnCdEmpresaWbc)         ,})
			aAdd(aFor, {"A2_XINTPA" , '2'                                            ,}) //Integrar
			
			conout(cvaltochar(ExistCpo("CC2",oFornec[nX]:csSgEstado+cCodMun,1)))
			
			/*If Len(oFornec[nX]:oWSlstEmpresaBanco:oWSEmpresaBancoDTO) > 0				
				aAdd(aFor, {"A2_BANCO"   , oFornec[nX]:oWSlstEmpresaBanco:oWSEmpresaBancoDTO[1]:csCdBanco         	,})
				aAdd(aFor, {"A2_AGENCIA" , oFornec[nX]:oWSlstEmpresaBanco:oWSEmpresaBancoDTO[1]:csCdAgencia       	,})
				If !Empty(oFornec[nX]:oWSlstEmpresaBanco:oWSEmpresaBancoDTO[1]:csCdAgenciaDigito)
					aAdd(aFor, {"A2_DIGAGE", oFornec[nX]:oWSlstEmpresaBanco:oWSEmpresaBancoDTO[1]:csCdAgenciaDigito ,})
				EndIf
				aAdd(aFor, {"A2_NUMCON"  , oFornec[nX]:oWSlstEmpresaBanco:oWSEmpresaBancoDTO[1]:csCdContaCorrente 	,})
				aAdd(aFor, {"A2_DIGCON"  , oFornec[nX]:oWSlstEmpresaBanco:oWSEmpresaBancoDTO[1]:csCdContaDigito  	,})
			EndIf*/
			If !Empty(NomeAutoLog())
				MemoWrite( NomeAutoLog(), ' ' )
			EndIf
			
			MSExecAuto({|x,y| mata020(x,y)}, aFor, 3)
			
			If !lMsErroAuto		
				conout(" Fornecedor " + SA2->A2_COD + SA2->A2_LOJA + " inserido com sucesso!")
				oLog:Retorno   := 1
				oLog:Origem    := cValToChar(oFornec[nX]:nnCdEmpresaWbc)
				oLog:MsgLog    := "Fornecedor " + SA2->A2_COD + SA2->A2_LOJA + " inserido com sucesso!"
				oLog:SoapFault := "Fornecedor " + SA2->A2_COD + SA2->A2_LOJA + " inserido com sucesso!"
				oLog:Tstamp    := FwTimeStamp(3)
				oLog:Token     := 'MATA020'		
				oLog:SalvaObj('SA2')
				
			Else		
				lerro := .T.
				conout(PADR(" ERROR - " + PADR(ProcName(1),10) + " - Tempo " +FWTimeStamp(2) +" - ",60) + 'Erro MATA020 ' + IIf(!Empty(NomeAutoLog()),MemoRead(NomeAutoLog()),''))
				oLog:Retorno   := 0
				oLog:Origem    := cValToChar(oFornec[nX]:nnCdEmpresaWbc)
				oLog:MsgLog    := 'Erro MATA020 - ' + IIf(!Empty(NomeAutoLog()),MemoRead(NomeAutoLog()),'')
				oLog:SoapFault := 'Erro MATA020 - ' + IIf(!Empty(NomeAutoLog()),MemoRead(NomeAutoLog()),'')
				oLog:Tstamp    := FwTimeStamp(3)
				oLog:Token     := 'MATA020'		
				oLog:SalvaObj('SA2')
				MemoWrite( NomeAutoLog(), ' ' )
			EndIf
			oLog:novoLog()
		Next nX
	Else
		fSoapFault(oLog)
		conout(PADR(" ERROR - " +PADR(ProcName(1),10) + " - Tempo " +FWTimeStamp(2) +" - ",60) + 'ERRO no metodo RetornarEmpresaVencedoraSemDePara ')
	EndIf

	fFimLog("Retorno de Fornecedores - " + cValToChar(nProc) + ' processados - ' + Time())
	End Sequence
	ErrorBlock(oError)
Return nProc

/*/{Protheus.doc} nProcForn
//Integra??o de fornecedores
@author Administrator
@since 01/05/2018
@version 2.0
@param oProcess, object, Objeto tNewProcess
@type function
/*/
Static Function nProcForn(oProcess)
	Local _cAlias:= GetNextAlias()
	Local cQuery := ""
	Local cMun   := ""
	Local cCod   := ""
	Local nProc  := 0
	Local oWsFor := WSEmpresa():New()
	Local oForne := Nil  
	Local aReg   := {}
	Local aEnd   := {}
	Local aSM0 	 := FWLoadSM0()
	Local oLog   := FwParLog():New("PAR001", "ProcessarEmpresa")
	Local oError := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'SA2', @oLog, @cCod)})
    Local nCont  := 0            
                 
	Begin Sequence
	fIniLog("Fornecedores")

 	SetRegua2(oProcess, 0)
 	IncRegua2(oProcess, "Fornecedores")

 	cQuery += " select   R_E_C_N_O_ REG "
 	cQuery += " from  " + RetSqlTab("SA2")
 	cQuery += " where " + RetSqlCond("SA2")
 	cQuery += "   and A2_CGC  <> ' ' "
 	cQuery += "   and A2_EST  <> 'EX' "
 	cQuery += "   and A2_XINTPA > '1' "
	cQuery += "   and A2_XINTPA < '5' "
 	//cQuery += "   AND ROWNUM <= 500"

	OPENSQL(_cAlias, cQuery)

	SetRegua2(oProcess,  (_cAlias)->( LastRec() ) )

 	while (_cAlias)->( ! EoF() )

 		SA2->( DbGoTo( (_cAlias)->REG ) )
 		             
 		nCont:= nCont+1 
 		
 		IncRegua2(oProcess, "Processando " + SA2->A2_COD + "/" + SA2->A2_LOJA)
 		
 		If Empty(aScan(aSM0, {|x| x[18] == AllTrim(SA2->A2_CGC) } ))

	 		cCod   := SA2->A2_COD + SA2->A2_LOJA
			dDtIni := SA2->A2_DTINIV
			dDtIni := IIf(Empty(dDtIni), SA2->A2_PRICOM, dDtIni)
			dDtIni := IIf(Empty(dDtIni), cToD('01/01/2018'), dDtIni)
			cMun   := POSICIONE('CC2', 1, xFilial('CC2')+SA2->A2_EST+SA2->A2_COD_MUN, 'CC2_MUN')
			aEnd   := {}
			aEnd   := Separa(SA2->A2_END, ",", .F.)
			
			aSize(aEnd, 2)
	
			oForne:= Empresa_EmpresaDTO():New()
			//oForne:nbFlAreaInfluencia 				:= //int
			//oForne:nbFlAtividadeComercial 			:= //int
			//oForne:nbFlAtividadeIndustrial 			:= //int
			//oForne:nbFlAtividadeServico 				:= //int
			//oForne:ndVlCapitalIntegralizado 			:= //decimal
			//oForne:ndVlCapitalSocial 					:= //decimal
			//oForne:ndVlPatrimonioLiquido 				:= //decimal
			//oForne:oWSlstDocumento 					:= //Empresa_ArrayOfCrcHistoricoDTO
			//oForne:oWSlstEmpresaBanco 				:= //Empresa_ArrayOfEmpresaBancoDTO
			//oForne:oWSlstEmpresaClasse 				:= //Empresa_ArrayOfEmpresaClasseDTO
			//oForne:oWSlstEmpresaContato 				:= //Empresa_ArrayOfEmpresaContatoDTO
			//oForne:oWSlstEmpresaEnderecoCobranca 		:= //Empresa_ArrayOfEmpresaEnderecoDTO
			//oForne:oWSlstEmpresaEnderecoEntrega 		:= //Empresa_ArrayOfEmpresaEnderecoDTO
			//oForne:oWSlstEmpresaEnderecoFaturamento 	:= //Empresa_ArrayOfEmpresaEnderecoDTO
			//oForne:oWSlstEmpresaEnderecoInstitucional := //Empresa_ArrayOfEmpresaEnderecoDTO
			If !Empty(SA2->A2_XEMPWBC)
				oForne:nnCdEmpresaWbc 		:= Val(SA2->A2_XEMPWBC)
			EndIf
			//oForne:nnCdIdioma 			:= //long
			oForne:nnCdSituacao 			:= IIf(SA2->A2_MSBLQL <> '1', 1, 0) //Ativa
			oForne:nnCdTipo 				:= 3 //Vendedora
			//oForne:nnCdTipoCadastroMap 	:= //int
			//oForne:nnIdSuperSimples 		:= //int
			oForne:nnIdTipoPessoa 			:= IIf(SA2->A2_TIPO == "F", 1, 2)
			//oForne:nnNrAutoAvaliacao 		:= //int
			//oForne:nnNrNotaAvaliacao 		:= //decimal
			//oForne:csCdAtividadeMap 		:= //string
			//oForne:csCdCnae 				:= '021001' //SA2->A2_CNAE
			oForne:csCdEmpresa 				:= IIf(Empty(SA2->A2_CGC), SA2->A2_COD + SA2->A2_LOJA, SA2->A2_CGC)
			//oForne:csCdEmpresaCliente 	:= //string
			//oForne:csCdEmpresaEnvio 		:= //string
			//oForne:csCdMoeda 				:= //string
			//oForne:csCdNaturezaJuridica 	:= //string
			//oForne:csCdUsarioHomologador	:= //string
			oForne:csDsCep 					:= SA2->A2_CEP
			oForne:csDsEmailContato 		:= SA2->A2_XEMAIL
			oForne:csDsEndereco 			:= aEnd[1]
			oForne:csNrEndereco 			:= aEnd[2]
			oForne:csDsEnderecoComplemento	:= SA2->A2_COMPLEM
			//oForne:csDsUrl 				:= //string
			oForne:csNmApelido 				:= SA2->A2_NREDUZ
			oForne:csNmBairro 				:= SA2->A2_BAIRRO
			oForne:csNmCidade 				:= AllTrim(Capital(Lower(AllTrim(IIf(Empty(cMun), SA2->A2_MUN, cMun)))))
			oForne:csNmContato 				:= SA2->A2_CONTATO
			oForne:csNmEmpresa 				:= SA2->A2_NOME
			oForne:csNmFantasia 			:= SA2->A2_NREDUZ
			//oForne:csNrCelular 			:= //string
			oForne:csNrCnpj 				:= IIf(Empty(SA2->A2_CGC), SA2->A2_COD, SA2->A2_CGC)
			//oForne:csNrCnpjMatriz 		:= //string
			oForne:csNrFax 					:= SA2->A2_FAX
			oForne:csNrInscricaoEstadual 	:= SA2->A2_INSCR
			oForne:csNrInscricaoMunicipal 	:= SA2->A2_INSCRM
			oForne:csNrTelefone 			:= SA2->A2_TEL
			oForne:csSgEstado 				:= AllTrim(SA2->A2_EST)
			//oForne:csSgGrupoConta 		:= //string
			oForne:csSgPais 				:= 'BR' //POSICIONE('SYA', 1, xFilial('SYA')+SA2->A2_PAIS, 'YA_PAISDUE')
			//oForne:ctDtCadastro 			:= FwTimeStamp(3, )
			oForne:ctDtInicioAtividade 		:= FwTimeStamp(3, dDtIni)
			//oForne:ctDtIntegralizacao 	:= //dateTime
			//oForne:ctDtValidadeCadastro 	:= //dateTime
	
			aAdd(aReg, (_cAlias)->REG)
			aAdd(oWsFor:oWSlstEmpresa:oWSEmpresaDTO, oForne:Clone())
		EndIf

		(_cAlias)->( DbSkip() )
		
		If nCont > 999
		
		   Exit
		   
		   nCont:= 0
		
		Endif
		
	endDo
 
 	CLOSESQL(_cAlias)
 
	If !Empty(oWsFor:oWSlstEmpresa:oWSEmpresaDTO)
 		//faz a chamada do m?todo de integra??o
	 	If oWsFor:ProcessarEmpresa()
			//registra o retorno de processar
			fWsLogRet( oWsFor:oWSProcessarEmpresaResult:oWSlstWbtLogDTO:oWSWbtLogDTO, oLog, "SA2", aReg, @nProc )	
		Else
			fSoapFault(oLog)
	 	EndIf
 	EndIf
 	
 	fFimLog("Fornecedores - " + cValToChar(nProc) + ' processados - ' + Time())
 	End Sequence
	ErrorBlock(oError)
Return nProc

/*/{Protheus.doc} nProcSC
//Efetua a integra??o de solicita??es de compras
@author fabricio.reche
@since 10/04/2018
@version 1.0
@param oProcess, object, Objeto de processamento tNewProcess
@type function
/*/
Static Function nProcSC(oProcess)
	Local _cAlias := GetNextAlias()
	Local cQuery  := ""
	Local cNum    := ''	
	Local cFilCGC := ''
	Local cFilEnt := ''
	Local cFilAux := cFilAnt
	Local oWsSc   := WSRequisicao():New()
	Local oSc     := Nil
	Local oCT	  := Nil
	Local oLog    := FwParLog():New("PAR001", "ProcessarRequisicao")
	Local nProc   := 0
	Local nPos    := 0
	Local nX      := 0
	Local aRecs   := {}
	Local aReg    := {}
	Local oError  := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'SC1', @oLog, @cNum)})
	Local cPA5CERCOD:= ""
	Local cRegra    := " "
	Local lRet   	:= .T.	

	Begin Sequence
		fIniLog("Solicitacao de Compras")

		SetRegua2(oProcess, 0)
		IncRegua2(oProcess, "Solicitacao de Compras")

		cQuery += " select R_E_C_N_O_ REG "
		cQuery += " from  " + RetSqlTab("SC1")
		cQuery += " where D_E_L_E_T_ = ' ' "
		cQuery += "   and C1_APROV  IN (' ', 'L') " //<> 'B' " R //liberados
		cQuery += "   and C1_EC05DB IN ('C','I','N','O', 'A',' ') " 
		cQuery += "   and C1_XINTPA > '1' "
		cQuery += "   and C1_XINTPA < '5' " // 108624, CHAMADO DO WALDIR 10/05/2022
 		cQuery += "   and C1_PEDIDO = ' ' "
		cQuery += "   and C1_FLAGGCT = ' ' "
			
		OPENSQL(_cAlias, cQuery)
	
		(_cAlias)->( DbEval({|| aAdd(aReg, REG)}))

		CLOSESQL(_cAlias)

		SetRegua2(oProcess, Len(aReg))

		For nX := 1 to Len(aReg)
			SC1->(DbGoTo(aReg[nX]))
			
			//SENSUS EM 09/03/2021                
			//Se C1_RATEIO = '1' verificar na SCX
			//CX_E505DB  IN ('C','I','N','O','A') "  //1) CX_FILIAL+CX_SOLICIT+CX_ITEMSOL+CX_ITEM
			//MAYCON MOTTA - RATEIO = '1'
			If SC1->C1_RATEIO == "1" .and. SC1->C1_EC05DB == "       " 
				
				//MsgAlert('UMA SC COM RATEIO ENCONTRADA NUMERO: ' + SC1->C1_NUM  +' TIPO: ' + SC1->C1_EC05DB +' STATUS: '+ SC1->C1_APROV + ' PRODUTO: ' + SC1->C1_PRODUTO + ' DESCRICAO: ' + SC1->C1_DESCRI, 'RATEIO ENCONTRADO NESSA IMPORTACAO') 

				SCX->( DbSetOrder(1) )
				SCX->( DbSeek( xFilial("SCX") + SC1->C1_NUM ) )
			
				cRegra:= SCX->CX_EC05DB

				conout("Regra rateio-> "+cRegra)
				conout("SC-> "+SC1->C1_NUM)
				
				If cRegra == "       "
					lRet:= .F.
				Endif 
				
			Endif 
			
			If SC1->C1_RATEIO == "2" .and. SC1->C1_EC05DB == "       " .or. cRegra == "       "
				conout("Regra sem-> "+SC1->C1_EC05DB)
				conout("SC-> "+SC1->C1_NUM)	
				lRet := .F.			
			Endif
			
			cFilAnt 	:= SC1->C1_FILIAL
			cNum    	:= SC1->C1_NUM
			oLog:Difere := SC1->C1_ITEM
			nPos   		:= aScan(aEmpFil, {|x| x[2] == cFilAnt})
			cFilCGC 	:= aEmpFil[nPos][18]
			nPos   		:= aScan(aEmpFil, {|x| x[2] == SC1->C1_FILENT})
			cFilEnt 	:= aEmpFil[nPos][18]
			
			SB1->( DbSetOrder(1) )
			SB1->( DbSeek( xFilial("SB1") + SC1->C1_PRODUTO ) )
			
			PA5->( DbSetOrder(1) )
			PA5->( DbSeek( xFilial("PA5") + SB1->B1_COD ) )
			While !PA5->(Eof()) .and. PA5->PA5_FILIAL+PA5->PA5_CERCOD == xFilial("PA5")+SB1->B1_COD

				cPA5CERCOD:= cPA5CERCOD+(PA5->PA5_CERCOD+" "+PA5_CERDES+" ") 
				
				PA5->(DbSkip())
			
			Enddo

			If cRegra == " "
				DO CASE  
					CASE AllTrim(SC1->C1_EC05DB) == 'C'
						nAplica := 1
					CASE AllTrim(SC1->C1_EC05DB) == 'I'
						nAplica := 2
					CASE AllTrim(SC1->C1_EC05DB) == 'N'
						nAplica := 3
					CASE AllTrim(SC1->C1_EC05DB) == 'O'
						nAplica := 5
					CASE AllTrim(SC1->C1_EC05DB) == 'B'
						nAplica := 1
					CASE AllTrim(SC1->C1_EC05DB) == 'A'
						nAplica := 7 
					OTHERWISE
						nAplica := 0
				ENDCASE
			ENDIF
				         
			If cRegra <> " "
				DO CASE  					
					CASE AllTrim(cRegra) == 'C'
						nAplica := 1
					CASE AllTrim(cRegra) == 'I'
						nAplica := 2
					CASE AllTrim(cRegra) == 'N'
						nAplica := 3
					CASE AllTrim(cRegra) == 'O'
						nAplica := 5
					CASE AllTrim(cRegra) == 'B'
						nAplica := 1
					CASE AllTrim(cRegra) == 'A'
						nAplica := 7
					OTHERWISE
						nAplica := 0
				ENDCASE			
			ENDIF
			
			aAdd(aRecs, aReg[nX])

			IncRegua2(oProcess, "Processando " + SC1->C1_NUM + "/" + SC1->C1_ITEM + ": " + SC1->C1_PRODUTO)

			oSc := Requisicao_RequisicaoDTO():New()
			oSc:ndQtEntrega 					:= SC1->C1_QUANT //SC1->C1_QUJE
			oSc:ndVlReferencia 				    := SB1->B1_UPRC
			// oSc:oWSlstRequisicaoEmpresaDTO	:= AS Requisicao_ArrayOfRequisicaoEmpresaDTO OPTIONAL
			// oSc:oWSlstRequisicaoIdioma 		:= AS Requisicao_ArrayOfRequisicaoIdiomaDTO OPTIONAL
			oSc:nnCdAplicacao 					:= nAplica
			// oSc:nnCdMarca 					:= AS long OPTIONAL
			oSc:nnCdMoeda 						:= 1
			oSc:nnCdOrigem 						:= 0 //AS long OPTIONAL
			oSc:nnCdSituacao 					:= 1   // encaminhada
			// oSc:nnIdTipoOrigem 				:= AS long OPTIONAL
			oSc:nnIdTipoRequisicao 	 			:= 1
			// oSc:oWSoAplicacaoDetalhe 		:= AS Requisicao_AplicacaoDetalheDTO OPTIONAL
			oCT := Requisicao_ContaContabilDetalheDTO():New()
			oCT:csDsContaContabil				:= AllTrim(SC1->C1_CONTA)
			oSc:oWSoContaContabilDetalhe 	    := oCT
			// oSc:oWSoCriterioDetalhe 			:= AS Requisicao_CriterioDetalheDTO OPTIONAL
			// oSc:oWSoMarcaDetalhe 			:= AS Requisicao_MarcaDetalheDTO OPTIONAL
			// oSc:oWSoNaturezaDespesaDetalhe 	:= AS Requisicao_NaturezaDespesaDetalheDTO OPTIONAL
			// oSc:oWSoUnidadeMedidaDetalhe 	:= AS Requisicao_UnidadeMedidaDetalheDTO OPTIONAL
			If !Empty(SC1->C1_CC)
				oSc:csCdCentroCusto 			:= AllTrim(SC1->C1_CC)
			EndIf
			//ALERT('conta:' + SC1->C1_CONTA)
			oSc:csCdClasse 						:= SB1->B1_GRUPO
			// oSc:csCdCobrancaEndereco 		:= AS string OPTIONAL
			If !Empty(SC1->C1_CONTA)
				oSc:csCdContaContabil 			:= AllTrim(SC1->C1_CONTA)
			EndIf
			// oSc:csCdDepartamento 			:= AS string OPTIONAL
			oSc:csCdEmpresa 					:= cFilCGC //cEmpAnt + SC1->C1_FILIAL
			oSc:csCdEmpresaCobrancaEndereco 	:= cFilCGC //cEmpAnt + SC1->C1_FILIAL
			oSc:csCdEmpresaEntregaEndereco 		:= cFilEnt //SM0->M0_CGC //cEmpAnt + SC1->C1_FILIAL
			oSc:csCdEmpresaFaturamentoEndereco  := cFilCGC //SM0->M0_CGC //cEmpAnt + SC1->C1_FILIAL
			// oSc:csCdEntregaEndereco 			:= AS string OPTIONAL
			// oSc:csCdFaturamentoEndereco 		:= AS string OPTIONAL
			// oSc:csCdFonteRecurso 			:= AS string OPTIONAL
			/*If !Empty(SC1->C1_GRUPCOM)
				oSc:csCdGrupoCompra 			:= SC1->C1_GRUPCOM
			EndIf*/
			oSc:csCdItemEmpresa 				:= SC1->C1_ITEM
			// oSc:csCdNaturezaDespesa 			:= AS string OPTIONAL
			oSc:csCdProduto 					:= AllTrim(SC1->C1_PRODUTO)
			oSc:csCdRequisicaoEmpresa 			:= SC1->C1_FILIAL + '.' + SC1->C1_NUM
			oSc:csCdUnidadeMedida 				:= SC1->C1_UM
			// oSc:csCdUnidadeNegocio 			:= AS string OPTIONAL
			oSc:csCdUsuarioComprador 			:= AllTrim(POSICIONE('ZUP', 1, SC1->C1_USER, 'ZUP_NOMRED'))
			oSc:csCdUsuarioResponsavel 			:= AllTrim(POSICIONE('ZUP', 1, SC1->C1_USER, 'ZUP_NOMRED'))
			// oSc:csDsAnexo 					:= AS string OPTIONAL
			// oSc:csDsDetalheCliente 			:= AS string OPTIONAL
			oSc:csDsJustIficativa 				:= AllTrim(SC1->C1_OBS)
			oSc:csDsObservacao 					:= IIf(Empty(SB1->B1_XVERSAO), '', ('Produto ' + AllTrim(SB1->B1_COD) + ' - MKT ' + AllTrim(SB1->B1_XVERSAO)))
			If !Empty(cPA5CERCOD) //AllTrim(PA5->PA5_CERDES))
				oSc:csDsObservacao 				+= ((IIf(Empty(oSc:csDsObservacao), '', CRLF)) + 'Produto ' + AllTrim(SB1->B1_COD) + ' - '  + (IIf('CA' $ cPA5CERCOD, '', 'CA ')) + AllTrim(cPA5CERCOD))
			EndIf
			oSc:csDsObservacao 					+= CRLF + oSc:csDsJustIficativa
			oSc:csDsObservacaoInterna 		    := AllTrim(SC1->C1_OBS)
			oSc:csDsProdutoRequisicao 			:= oSc:csCdProduto + ' - ' + AllTrim(SC1->C1_DESCRI)
			oSc:ctDtCriacao 					:= FwTimeStamp(3, SC1->C1_EMISSAO)
			oSc:ctDtEntrega 					:= FwTimeStamp(3, SC1->C1_DATPRF)
			// oSc:ctDtLiberacao 				:= AS dateTime OPTIONAL
			// oSc:ctDtMoedaCotacao 			:= AS dateTime OPTIONAL
			oSc:ctDtProcesso 					:= FwTimeStamp(3)
			
			conout('__' + UsrRetName(SC1->C1_USER))

			aAdd(oWsSc:oWSlstRequisicao:oWSRequisicaoDTO, oSc:Clone())
			
			if lRet == .F.
				aDel(oWsSc:oWSlstRequisicao:oWSRequisicaoDTO, nX)
			EndIf
		Next nX

		If !Empty(oWsSc:oWSlstRequisicao:oWSRequisicaoDTO)
			//faz a chamada do m?todo de integra??o
			If oWsSc:ProcessarRequisicao()
				//registra o retorno de processar
				fWsLogRet( oWsSc:oWSProcessarRequisicaoResult:oWSlstWbtLogDTO:oWSWbtLogDTO, oLog, "SC1", aRecs, @nProc )	
			Else
				fSoapFault(oLog)
			EndIf
		EndIf

		fFimLog("Solicitacao de Compras - " + cValToChar(nProc) + ' processados - ' + Time())
		cFilAnt := cFilAux
	End Sequence
	ErrorBlock(oError)
Return nProc

/*/{Protheus.doc} nCancelSC
//VerIfica cancelamentos de SC via o portal paradigma
@author fabricio.reche
@since 02/05/2018
@version 1.0
@param oProcess, object, objeto tNewProccess
@type function
/*/
Static Function nCancelSC(oProcess)
	Local oLog   := FwParLog():New("PAR001", "RetornarRequisicaoCancelamento")
	Local nProc  := 0
	Local oWsSc  := WSRequisicao():New()
	
	fIniLog("Cancelamento de Solicitacao de Compras")

	If oWsSc:RetornarRequisicaoCancelamento()
		cancelSC(oWsSc:oWSRetornarRequisicaoCancelamentoResult:oWSRequisicaoAtualizarDTO, oLog, @nProc)
	Else
		fSoapFault(oLog)
	EndIf
	
	fFimLog("Cancelamento de Solicitacao de Compras - " + cValToChar(nProc) + ' processados - ' + Time())

Return nProc

/*/{Protheus.doc} cancelSC
//Execu??o da rotina autom?tica para cancelamento da SC
@author fabricio.reche
@since 05/2018
@version 2.0
@param oWSRequisicaoAtualizarDTO, object; nProc, numeric
@type function
/*/
Static Function cancelSC(oWSRequisicaoAtualizarDTO, oLog, nProc)
	Local aCabec  := {}
	Local aLinha  := {}
	Local oCa     := {}
	Local oCancel := Nil
	Local nX      := 0
	Local nPos	  := 0
	Local cNum    := ''
	Local cFilAux := cFilAnt
	Local oError  := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'SC1', @oLog, @cNum)})
	
	Begin Sequence
		For nX := 1 To Len(oWSRequisicaoAtualizarDTO)
			lMsErroAuto := .F.
			aCabec      := {}
			aLinha      := {}
			aNum        := Separa(oWSRequisicaoAtualizarDTO[nX]:csCdRequisicaoEmpresa, '.', .T.)
			cNum        := IIf(Len(aNum) == 2 .And. !Empty(aNum[2]), aNum[2], aNum[1])
			nPos      	:= aScan(aEmpFil, {|x| x[18] == oWSRequisicaoAtualizarDTO[nX]:csCdEmpresa})
			cFilAnt   	:= aEmpFil[nPos][2]
				
			dbSelectArea("SC1")
			dbSetOrder(1)
			If dbSeek(xFilial('SC1')+cNum+oWSRequisicaoAtualizarDTO[nX]:csCdItemEmpresa)
				RecLock("SC1",.F.)
				SC1->C1_XINTPA  := ' '
				SC1->C1_COTACAO := ' '
				MsUnLock()
				
				conout("RetornarRequisicaoCancelamento " + cNum + " Executado Com Sucesso!")
				oLog:Retorno   := 1
				oLog:Origem    := cNum
				oLog:MsgLog    := "RetornarRequisicaoCancelamento " + cNum + " Executado Com Sucesso!"
				oLog:SoapFault := "RetornarRequisicaoCancelamento " + cNum + " Executado Com Sucesso!"
				oLog:Tstamp    := FwTimeStamp(3)
				oLog:Token     := 'Solicitacao de Compra'		
				oLog:SalvaObj('SC1')
			Else
				conout(PADR(" ERROR - " +PADR(ProcName(1),10) + " - Tempo " +FWTimeStamp(2) +" - ",60) + 'RetornarRequisicaoCancelamento. Requisicao nao encontrada no sistema: ' + cNum)			
				oLog:Retorno   := 0
				oLog:Origem    := cNum
				oLog:MsgLog    := 'Solicitacao de compra ' + cNum + ' nao encontrada.'
				oLog:SoapFault := 'Solicitacao de compra ' + cNum + ' nao encontrada.'
				oLog:Tstamp    := FwTimeStamp(3)
				oLog:Token     := 'MATA110'		
				oLog:SalvaObj('SC1')
				
				oLog:novoLog()
				oLog:Funcao := 'HabilitarRetornarRequisicaoCancelamento'
				oCancel     := WSRequisicao():New()
				aAdd(oCancel:oWSsCdRequisicaoEmpresa:cstring, oWSRequisicaoAtualizarDTO[nX]:csCdRequisicaoEmpresa)
				
				If !oCancel:HabilitarRetornarRequisicaoCancelamento()
					fSoapFault(oLog)
					conout(PADR(" ERROR - " +PADR(ProcName(1),10) + " - Tempo " +FWTimeStamp(2) +" - ",60) + 'Erro no HabilitarRetornarRequisicaoCancelamento()')
				EndIf
			EndIf
			
			nProc++
			oLog:novoLog()
		Next nX
		cFilAnt := cFilAux
	End Sequence
	ErrorBlock(oError)
Return

/*/{Protheus.doc} nEnviaPC
//Efetua a integra??o de pedidos de compras
@author fabricio.reche
@since 10/04/2018
@version 1.0
@param oProcess, object, Objeto de processamento tNewProcess
@type function
/*/
Static Function nEnviaPC(oProcess)
	Local cAliaTx  := ''
	Local _cAlias  := GetNextAlias()
	Local oWsPc    := WSParPedido():New()
	Local oLog     := FwParLog():New("PAR001", "ProcessarPedido")
	Local oPcIt    := Nil
	Local oPc      := Nil
	Local oPcEn    := Nil
	Local oPcTx    := Nil
	Local dQuant   := 0
	Local nProc    := 0
	Local nX       := 0
	Local nQuje    := 0
	Local nSitIt   := 0
	Local nSitPed  := 0
	Local aPedidos := {}
	Local cQuery   := ""
	Local cNum     := ""
	Local cEntrega := ""
	Local cTransp  := ""
	Local lEntrega := .F.
	Local cFilAux  := cFilAnt
	Local oError   := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'SC7', @oLog, @cNum)})

	Default aReg := {}

	Begin Sequence
		fIniLog("Pedido de Compras")

		SetRegua2(oProcess, 0)
		IncRegua2(oProcess, "Pedido de Compras")

		cQuery := " select  R_E_C_N_O_ REG, C7_FILIAL, C7_NUM "
		cQuery += " from  " + RetSqlTab("SC7")
		cQuery += " where D_E_L_E_T_ = ' ' "
		cQuery += "   and C7_CONAPRO  <> 'B' " //liberados
		cQuery += "   and C7_XINTPA    > '1' " 
		cQuery += "   and C7_XINTPA    < '5' " 
		cQuery += "   and C7_PO_EIC = ' ' "
		cQuery += "   and C7_ORIGEM <> 'MNTA650' " //N?o integrar pedidos vindo do MNTA650 - Manuten??o de Ativos.
		
		OPENSQL(_cAlias, cQuery)
		(_cAlias)->( DbEval({|| aAdd(aReg, REG) }) )
		(_cAlias)->( DbEval({|| aAdd(aPedidos, (C7_FILIAL + C7_NUM)) }, {|| aScan(aPedidos, (C7_FILIAL + C7_NUM)) == 0}) )
		CLOSESQL(_cAlias)
		
		conout(' ' + cValToChar(len(aPedidos)) + ' Pedidos' )
		
		SetRegua2(oProcess,  Len(aReg) )

		for nX := 1 to Len(aPedidos)
			oWsPc := WSParPedido():New()
			
			DbSelectArea('SC7')
			dbSetOrder(1)
			SC7->(dbSeek(aPedidos[nX]))
	
			IncRegua2(oProcess, "Processando " + SC7->C7_NUM + "/" + SC7->C7_ITEM + ": " + SC7->C7_PRODUTO)
			
			cFilAnt := SC7->C7_FILIAL
			cNum    := SC7->C7_NUM
			nSitPed := IIf(SC7->C7_CONAPRO == 'R', 4, IIf(( SC7->C7_XINTPA > '4'), 1, 5))
			conout(' _Situacao Pedido: ' + cValToChar(nSitPed) + ' - ' + cValToChar(SC7->C7_QUJE) )
			lEntrega := SC7->C7_XINTPA > '4'
			nPos   	 := aScan(aEmpFil, {|x| x[2] == cFilAnt})
			cFilCGC  := aEmpFil[nPos][18]
			nPos   	 := aScan(aEmpFil, {|x| x[2] == SC7->C7_FILENT})
			cFilEnt  := aEmpFil[nPos][18]
			
			dbSelectArea("SA2")
			dbSetOrder(1)  //A2_FILIAL+A2_COD+A2_LOJA
			dbSeek(xFilial('SA2')+SC7->C7_FORNECE+SC7->C7_LOJA)

			oPc:= Pedido_PedidoDTO():New()
			//oPc:oWSlstAnexo 			:= // Pedido_ArrayOfAnexoDTO
			//oPc:nnCdSituacao 			:= nSitPed // 1?Confirmado, 5?Em confirma??o do fornecedor
			oPc:nnCdTipo 				:= 1
			oPc:nnIdTipoOrigem 			:= SC7->C7_XTPORIG //0 - ERP, 1 ? Leil?o, 2 ? Cota??o
			If !Empty(SC7->C7_CC)
				oPc:csCdCentroCusto 	:= AllTrim(SC7->C7_CC)
			EndIf
			oPc:csCdComprador 			:= cFilCGC //SM0->M0_CGC
			oPc:csCdCondicaoPagamento 	:= SC7->C7_COND
			//oPc:nnCdOrigem			:= 3
			//oPc:csCdFonteRecurso 		:= // string
			oPc:csCdFornecedor 			:= IIf(Empty(SA2->A2_CGC), SA2->A2_COD, SA2->A2_CGC)
			oPc:csCdFrete 				:= IIf(Empty(SC7->C7_TPFRETE), 'C', SC7->C7_TPFRETE)
			//If !Empty(SC7->C7_GRUPCOM)
			//	oPc:csCdGrupoCompra 	:= SC7->C7_GRUPCOM
			//EndIf
			oPc:csCdMoeda 				:= cValToChar(SC7->C7_MOEDA)
			oPc:csCdPedidoERP 			:= SC7->C7_FILIAL + '.' + SC7->C7_NUM
			If !Empty(SC7->C7_XPEDWBC)
				oPc:csCdPedidoWBC 	    := AllTrim(SC7->C7_XPEDWBC)
			EndIf
			oPc:csCdUsuario 			:= AllTrim(POSICIONE('ZUP', 1, SC7->C7_USER, 'ZUP_NOMRED')) //Alessandro habilitar  //UsrRetName(SC7->C7_USER) 'WILLIAN' 
			//oPc:csCdUsuarioProgramador:= // string
			//oPc:csDsObservacoes 		:= // string
			//oPc:csDsPedidoAuditoria 	:= // string
			//oPc:csNrProjeto 			:= // string
			//oPc:csNrRgPesquisador 	:= // string
			oPc:ctDtCadastro 			:= FwTimeStamp(3, SC7->C7_EMISSAO)
			oPc:ctDtEmissao 			:= FwTimeStamp(3, SC7->C7_EMISSAO)
			//oPc:ctDtFaturamento 		:= // dateTime

			oPc:oWSlstPedidoItem 		:= Pedido_ArrayOfPedidoItemDTO():New()
			oPc:ndVlTotal 				:= 0
			
			cEntrega := ""
			nQuje    := 0
			while SC7->(!EoF()) .And. SC7->C7_FILIAL == cFilAnt .And. SC7->C7_NUM == cNum
			
				cQuery := " select R_E_C_N_O_ REG, C7_FILIAL, C7_NUM "
				cQuery += " from  " + RetSqlTab("SC7")
				cQuery += " where " + RetSqlCond("SC7")
				cQuery += "   and C7_NUM     = " + ValToSql(cNum)
				cQuery += "   and C7_PRODUTO = " + ValToSql(SC7->C7_PRODUTO)
				cQuery += "   and C7_XITWBC  = " + ValToSql(SC7->C7_XITWBC)
				cQuery += "   and C7_ITEM    > " + ValToSql(SC7->C7_ITEM)
		
				OPENSQL(_cAlias, cQuery)		 	
				
				oPc:ndVlTotal += SC7->C7_TOTAL
				
				SB1->( DbSetOrder(1) )
				SB1->( DbSeek( xFilial("SB1") + SC7->C7_PRODUTO ) )
				
				dQuant := 0
				If lEntrega
					cASD1  := GetNextAlias()
					cQuery := " SELECT R_E_C_N_O_ REG, D1_QUANT "
					cQuery += "   FROM " + RetSqlTab("SD1")
					cQuery += "  WHERE " + RetSqlCond("SD1")
					cQuery += "    AND D1_PEDIDO = " + ValToSql(SC7->C7_NUM)
					cQuery += "    AND D1_ITEMPC = " + ValToSql(SC7->C7_ITEM)
					//cQuery += "   GROUP BY A6_COD, A6_NOME  "
					//cQuery += " order by A6_COD, A6_NOME "
					cQuery := ChangeQuery(cQuery)
					DbUseArea(.T.,'TOPCONN',TCGenQry(,,cQuery),cASD1,.T.,.F.)
					While (cASD1)->(!EoF())
						dQuant := (cASD1)->D1_QUANT
						(cASD1)->(DbSkip())
					EndDo
					DbCloseArea()
				EndIf
				
				If cEntrega <> (SC7->C7_PRODUTO + SC7->C7_XITWBC)
					nQuje := SC7->C7_QUJE
					oPcIt := Pedido_PedidoItemDTO():New()
					
					oPcIt:ndPcDesconto 				:= SC7->C7_DESC
					oPcIt:ndQtItem 					:= Iif(lEntrega, dQuant,SC7->C7_QUANT)
					oPcIt:ndVlItem 					:= SC7->C7_PRECO
					oPcIt:csCdClasse 				:= SB1->B1_GRUPO
					oPcIt:csCdEmpresa 				:= cFilCGC //SM0->M0_CGC
					oPcIt:csCdItemEmpresa 		    := SC7->C7_ITEM 
					oPcIt:csCdItemOrigemEmpresa 	:= SC7->C7_ITEMSC
					If !Empty(SC7->C7_XITWBC)
						oPcIt:csCdItemWbc 			:= AllTrim(SC7->C7_XITWBC) // item da cota??o
					EndIf
					oPcIt:csCdOrigemEmpresa 		:= SC7->C7_NUMSC
					oPcIt:csCdProduto 				:= AllTrim(SC7->C7_PRODUTO)
					oPcIt:csCdUnidadeMedida 		:= SC7->C7_UM
					oPcIt:csCdUsuarioResponsavel 	:= AllTrim(POSICIONE('ZUP', 1, SC7->C7_USER, 'ZUP_NOMRED'))  //UsrRetName(SC7->C7_USER)
					oPcIt:csDsItem 					:= AllTrim(SB1->B1_DESC)
					//oPcIt:csDsObservacao 			:= AllTrim(SC7->C7_OBS)
					
					oPcIt:oWSlstPedidoItemEntrega   := Pedido_ArrayOfPedidoItemEntregaDTO():New()
					
					oPcIt:oWSlstPedidoItemTaxa      := Pedido_ArrayOfPedidoItemTaxaDTO():New()
				
					/*oPcTx                := Pedido_PedidoItemTaxaDTO():New()
					oPcTx:nbFlIncluso    := IIf(SC7->C7_PICM > 0, 1, 0)
					oPcTx:ndPcTaxa       := SC7->C7_PICM
					oPcTx:nnCdTaxa       := 1			
					aAdd(oPcIt:oWSlstPedidoItemTaxa:oWSParPedidoItemTaxaDTO, oPcTx)*/
					
					oPcTx                := Pedido_PedidoItemTaxaDTO():New()
					oPcTx:nbFlIncluso    := IIf(SC7->C7_IPI > 0, 1, 0)
					oPcTx:ndPcTaxa       := SC7->C7_IPI
					oPcTx:nnCdTaxa       := 2			
					aAdd(oPcIt:oWSlstPedidoItemTaxa:oWSParPedidoItemTaxaDTO, oPcTx)
					
					oPcTx                := Pedido_PedidoItemTaxaDTO():New()
					oPcTx:nbFlIncluso    := IIf(SC7->C7_ICMSRET > 0, 1, 0)
					oPcTx:ndPcTaxa       := SC7->C7_ICMSRET //IIf(SC7->C7_ICMSRET > 0, Round((SC7->C7_ICMSRET * 100) / SC7->C7_TOTAL, 2), 0)
					oPcTx:nnCdTaxa       := 3
					aAdd(oPcIt:oWSlstPedidoItemTaxa:oWSParPedidoItemTaxaDTO, oPcTx)
					
					cAliaTx := GetNextAlias()
					cQuery := " select R_E_C_N_O_ REG, ZIP_INCLUS, ZIP_TAXA "
					cQuery += "  from " + RetSqlTab("ZIP")
					cQuery += " where " + RetSqlCond("ZIP")
					cQuery += "   and ZIP_NUM    = " + ValToSql(SC7->C7_NUM)
					cQuery += "   and ZIP_ITEM   = " + ValToSql(SC7->C7_ITEM)
					cQuery += "   and ZIP_ITEPAR = " + ValToSql(SC7->C7_XITWBC)
					cQuery += "   and ZIP_PROPOS = " + cValToChar(SC7->C7_XPROPOS)
					cQuery += "   and ZIP_CODTAX = " + cValToChar(5)		
					OPENSQL(cAliaTx, cQuery)
					If (cAliaTx)->(!EoF())
						oPcTx             := Pedido_PedidoItemTaxaDTO():New()
						oPcTx:nbFlIncluso := (cAliaTx)->ZIP_INCLUS
						oPcTx:ndPcTaxa    := (cAliaTx)->ZIP_TAXA
						oPcTx:nnCdTaxa    := 5
						aAdd(oPcIt:oWSlstPedidoItemTaxa:oWSParPedidoItemTaxaDTO, oPcTx)
					EndIf
					CLOSESQL(cAliaTx)
				Else
					oPcIt:ndQtItem += SC7->C7_QUANT
					nQuje          += SC7->C7_QUJE
				EndIf
				
				If nSitPed == 4
					nSitIt := 4
				ElseIf nSitPed == 5
					nSitIt := 5
				Else
					nSitIt := IIf(nQuje == 0, 1, IIf(SC7->C7_QUANT <> SC7->C7_QUJE, 16, 15))
				EndIf
				oPcIt:nnCdSituacao := nSitIt // 1-Confirmado, 4-Cancelado, 5-A confirmar, 15-Entrega total, 16-Entrega parcial
				oPc:nnCdSituacao   := nSitIt
				
				cEntrega := SC7->C7_PRODUTO + SC7->C7_XITWBC
				
				oPcEn                                := Pedido_PedidoItemEntregaDTO():New()
				oPcEn:ndQtEntrega                	 := Iif(lEntrega, dQuant, SC7->C7_QUANT)
				oPcEn:ndQtItemRealizado              := SC7->C7_QUJE
				If !Empty(SC7->C7_CC)
					oPcEn:csCdCentroCustoRequisicao      := AllTrim(SC7->C7_CC)
				EndIf
				//oPcEn:csCdCobrancaEndereco         := AllTrim(SM0->M0_ENDCOB)
				oPcEn:csCdEmpresaCobrancaEndereco    := cFilCGC //SM0->M0_CGC
				oPcEn:csCdEmpresaEntregaEndereco     := cFilEnt //SM0->M0_CGC
				//oPcEn:csCdEntregaEndereco     		 := cFilEnt //SM0->M0_CGC
				oPcEn:csCdEmpresaFaturamentoEndereco := cFilCGC //SM0->M0_CGC
				//oPcEn:csCdEntregaEndereco          := AllTrim(SM0->M0_ENDCOB)
				//oPcEn:csCdFaturamentoEndereco      := AllTrim(SM0->M0_ENDCOB)
				//oPcEn:csCdItemEntregaEmpresa       AS string OPTIONAL
				oPcEn:csCdItemRequisicaoEmpresa      := SC7->C7_ITEMSC
				oPcEn:csCdRequisicaoEmpresa          := SC7->C7_FILIAL + '.' + SC7->C7_NUMSC
				oPcEn:ctDtEntrega                    := FwTimeStamp(3, SC7->C7_DATPRF)
				oPcEn:nnCdPedidoSituacaoEntrega		 := nSitIt
				//oPcEn:ndQtPorUnidade               AS decimal OPTIONAL
				//oPcEn:ndQtUnidade                  AS decimal OPTIONAL
				//oPcEn:nnQtDiasEntrega              AS decimal OPTIONAL
				//oPcEn:csCdAlmoxarIfado             AS string OPTIONAL
				//oPcEn:csCdAlmoxarIfadoDoca         AS string OPTIONAL
				//oPcEn:csCdItemEntregaEmpresa       AS string OPTIONAL
				//oPcEn:csCdUnidadeFornecimento      AS string OPTIONAL
				//oPcEn:ctDtColeta                   AS dateTime OPTIONAL
				
				aAdd(oPcIt:oWSlstPedidoItemEntrega:oWSParPedidoItemEntregaDTO, oPcEn)
				
				If SC7->C7_QUANT <> SC7->C7_QUJE .And. SC7->C7_QUJE > 0
					oPcEn := Pedido_PedidoItemEntregaDTO():New()
					oPcEn:ndQtEntrega                	 := SC7->C7_QUANT - SC7->C7_QUJE
					oPcEn:csCdEmpresaCobrancaEndereco    := cFilCGC //SM0->M0_CGC
					oPcEn:csCdEmpresaEntregaEndereco     := cFilEnt //SM0->M0_CGC
					//oPcEn:csCdEntregaEndereco     		 := cFilEnt //SM0->M0_CGC
					oPcEn:csCdEmpresaFaturamentoEndereco := cFilCGC //SM0->M0_CGC
					oPcEn:ctDtEntrega                    := FwTimeStamp(3, SC7->C7_DATPRF)
					oPcEn:nnCdPedidoSituacaoEntrega		 := '16' // Entrega Parcial - Sensus 24/05/21 #4818
					aAdd(oPcIt:oWSlstPedidoItemEntrega:oWSParPedidoItemEntregaDTO, oPcEn)
				EndIf
						
				If (_cAlias)->(EoF())
					aAdd(oPc:oWSlstPedidoItem:oWSParPedidoItemDTO, oPcIt)
				EndIf

				CLOSESQL(_cAlias)
				SC7->( DbSkip() )
			EndDo

			aAdd(oWsPc:oWSlstPedido:oWSParPedidoDTO, oPc:Clone())
			
			//faz a chamada do m?todo de integra??o
			If oWsPc:ProcessarPedido()
				//registra o retorno de processar
				fLogRetWs( oWsPc:oWSProcessarPedidoResult:oWSlstWbtLogDTO:oWSWbtLogDTO, oLog, "SC7", aPedidos[nX], @nProc )	
			Else
				fSoapFault(oLog)
			EndIf

		next nX
		
		fFimLog("Pedido de Compras - " + cValToChar(nProc) + ' processados - ' + Time())
		cFilAnt := cFilAux
 	End Sequence
	ErrorBlock(oError)
Return nProc

/////////////////////////////////////////////////////////
// *************************************************** //
/////////////////////////////////////////////////////////
Static Function nRetCotaca(oProcess)
	Local oLog    := FwParLog():New("PAR001", "RetornarCotacaoItem")
	Local oWsPc   := WSParCotacao():New()
	Local nProc	  := 0
	Local nR	  := 0
	fIniLog("Retorno de Itens de Cotacao")

	If oWsPc:RetornarCotacaoItem()
		For nR := 1 To Len(oWsPc:oWSRetornarCotacaoItemResult:oWSParCotacaoDTO)
			oLog := FwParLog():New("PAR001", "RetornarCotacaoItem")
			
			fCotacao(oWsPc:oWSRetornarCotacaoItemResult:oWSParCotacaoDTO[nR], oLog) 
			
			If oWsPc:oWSRetornarCotacaoItemResult:oWSParCotacaoDTO[nR]:nnIdTipoNegociacao == 1 //Pedido
				fGeraPC(oWsPc:oWSRetornarCotacaoItemResult:oWSParCotacaoDTO[nR], oLog, @nProc)
			Else //Contrato
				fContrato(oWsPc:oWSRetornarCotacaoItemResult:oWSParCotacaoDTO[nR], oLog, @nProc)
			EndIf
		Next nR		
	Else
		fSoapFault(oLog)
		conout(PADR("ERROR - " +PADR(ProcName(1),10) + " - Tempo " +FWTimeStamp(2) +" - ",60) + 'ERRO no metodo RetornarCotacaoItem ')
	EndIf
	
	oLog  := FwParLog():New("PAR001", "RetornarPedidoLeilao")
	oWsPc := WSParPedido():New()
	If oWsPc:RetornarPedidoLeilao()
		lGeraPC(oWsPc:oWSRetornarPedidoLeilaoResult:oWSParPedidoDTO, oLog, @nProc)		
	Else
		fSoapFault(oLog)
		conout(PADR("ERROR - " +PADR(ProcName(1),10) + " - Tempo " +FWTimeStamp(2) +" - ",60) + 'ERRO no metodo RetornarPedidoLeilao ')
	EndIf
	
	fFimLog("Retorno de Pedido de Compras - " + cValToChar(nProc) + ' processados - ' + Time())
	
Return nProc

/*/{Protheus.doc} fGeraPC
//Gera o pedido de compras conforme pedido do portal
@author fabricio.reche
@since 23/05/2018
@version 2.0
@param oWSParPedidoDTO, object, objeto de retorno do pedido do portal
@param cNumSC, characters, N?mero da solicita??o de compras
@type function
/*/
Static Function fGeraPC(oWSParCotacaoDTO, oLog, nProc)
	Local aMt120Cb := {}
	Local aMt120It := {}
	Local aMata120 := {}
	Local aEntrega := {}
	Local aPropEnd := {}
	Local aTaxa    := {}
	Local aItens   := {}
	Local aPedWS   := {}
	Local aPedido  := {}
	Local allProp  := {}
	Local aErro    := {}
	Local lProblem := .F.
	Local nX       := 0
	Local nY       := 0
	Local nZ       := 0
	Local nW       := 0
	Local nE	   := 0
	Local nPos     := 0
	Local cErro    := ''
	Local cNum     := ''
	Local cItem    := ''
	Local cPedWS   := ''
	Local cQuery   := ''
	Local _cAlias  := ''
	Local cAliCo   := ''
	Local cOrigem  := ''
	Local cNumCot  := ''
	Local cCodUsua := ''
	Local cUsuario := ''
	Local cUserAux := __cUserID
	Local cDifere  := ''
	Local cFilAux  := cFilAnt
	Local oError   := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'SC7', @oLog, @cPedWS, @nY, @oWSParCotacaoDTO, @cOrigem, @cDifere, @nX)})
	
	Private lMsErroAuto := .F.
	dbSelectArea("ZPL")
	dbSelectArea("SC7")
	dbSetOrder(1)
	
	oLog:Usuario := oWSParCotacaoDTO:csCdUsuario
	cPedWS  := oWSParCotacaoDTO:csCdCotacaoWbc
	aItens  := oWSParCotacaoDTO:oWSlstCotacaoItemDTO:oWSParCotacaoItemDTO
	cOrigem := oWSParCotacaoDTO:csCdCotacaoERP + ' ' + cPedWS
	
	cUsuario  := PADR(oWSParCotacaoDTO:csCdUsuario, tamsx3("ZUP_NOMRED")[1])
	cCodUsua  := POSICIONE('ZUP', 2, cUsuario, 'ZUP_CODUSU')
	cUserAux  := __cUserID
	If !Empty(cCodUsua)
		__cUserID := cCodUsua
	EndIf
	Conout(' Criar Pedido. sCdUsuario: ' + oWSParCotacaoDTO:csCdUsuario + ' cCodUsua: ' + cCodUsua + ' cUserAux: ' + cUserAux + ' ')
			
	For nX := 1 To Len(aItens)
		If aItens[nX]:nnCdSituacao == 6
			Conout(' :: PARADIGMA :: Cotacao ' + cOrigem  + ' - item ' + aItens[nX]:csCdItemWbc + ' cancelado!')
			Loop
		EndIf
		aEndereco := aItens[nX]:oWSlstCotacaoItemEnderecoDTO:oWSParCotacaoItemEnderecoDTO
		aProposta := aItens[nX]:oWSlstCotacaoPropostaDTO:oWSParCotacaoPropostaDTO
		cOrigem   := oWSParCotacaoDTO:csCdCotacaoERP + ' ' + cPedWS + '-' + aItens[nX]:csCdItemWbc
		If Empty(aEndereco[1]:csCdRequisicaoEmpresa)
			Conout(' :: PARADIGMA :: Cotacao ' + cOrigem + ' sem requisicao!')
			Loop
		EndIf
		aNumSC  := Separa(aEndereco[1]:csCdRequisicaoEmpresa, ".", .T.)
		cFilAnt := aNumSC[1]
		cCgcEnt := IIf(Empty(aEndereco[1]:csCdEntregaEndereco), aEndereco[1]:csCdEmpresaEntregaEndereco, aEndereco[1]:csCdEntregaEndereco)
		nPos    := aScan(aEmpFil, {|x| x[18] == cCgcEnt})
		cFilEnt := aEmpFil[nPos][2]
		
		For nZ := 1 To Len(aProposta)
			If aProposta[nZ]:nnIdVencedor == 0
				Loop
			EndIf
			cDifere     := cValToChar(aProposta[nZ]:nnCdProposta)
			cOrigem     := oWSParCotacaoDTO:csCdCotacaoERP + ' ' + cPedWS + '-' + aItens[nX]:csCdItemWbc + ' ' + cDifere
			aPropEnd    := aProposta[nZ]:oWSlstCotacaoPropostaEnderecoDTO:oWSParCotacaoPropostaEnderecoDTO
			aTaxa       := aProposta[nZ]:oWSlstCotacaoPropostaTaxaDTO:oWSParCotacaoPropostaTaxaDTO
			aPedWS      := {}
			aMt120Cb    := {}
			//aMt120It    := {}
			lMsErroAuto := .F.
			lProblem    := .F.
			
			cNumSC      := IIf(Len(aNumSC) == 2 .And. !Empty(aNumSC[2]), aNumSC[2], aNumSC[1])
		
			_cAlias:= GetNextAlias()
			cQuery := " select C7_NUM NUM from  " + RetSqlTab("SC7")
		 	cQuery += " where D_E_L_E_T_ = ' ' "
		 	cQuery += "   and C7_NUMSC   = '" + cNumSC + "' "
		 	cQuery += "   and C7_ITEMSC  = '" + aEndereco[1]:csCdItemRequisicaoEmpresa + "' "
		 	cQuery += "   and C7_XPEDWBC = '" + cPedWS + "' "
		 	cQuery += "   and C7_XITWBC  = '" + aItens[nX]:csCdItemWbc + "' "
		 	cQuery += "   and C7_XPROPOS = "  + cValToChar(aProposta[nZ]:nnCdProposta)
			OPENSQL(_cAlias, cQuery)
			dbSelectArea(_cAlias)
		 	If (_cAlias)->( ! EoF() )
		 		cErro := 'Ja existe o pedido ' + (_cAlias)->NUM + ' com a solicitacao ' + aEndereco[1]:csCdRequisicaoEmpresa + ' ' + aEndereco[1]:csCdItemRequisicaoEmpresa
		 		Conout(cErro)
		 		oLog:Retorno   := 0
				oLog:Origem    := cOrigem
				oLog:MsgLog    := 'Erro: ' + cErro
				oLog:SoapFault := 'Erro: ' + cErro
				oLog:Tstamp    := FwTimeStamp(3)
				oLog:Token     := 'Gera Pedido'
				oLog:DIfere    := cDifere
				oLog:SalvaObj('SC7')
				oLog:novoLog()
		 		lProblem := .T.
		 		CLOSESQL(_cAlias)
		 		Loop		 		
		 	EndIf
		 	CLOSESQL(_cAlias)
			
			aADD(allProp, {aProposta[nZ]:nnCdProposta, StoD(Left(StrTran(aProposta[nZ]:ctDtValidade, "-", ""), 8))})
			
			cAux := aProposta[nZ]:csCdEmpresa + '.' + aProposta[nZ]:csCdCondicaoPagamento + '.' + aProposta[nZ]:csCdFrete + '.' + cFilAnt
		 	If aScan( aPedido, { |x| x[1] == cAux }) == 0
		 		/*If Empty(cNum)
					_cAlias:= GetNextAlias()
					cQuery := " select max(SC7.C7_NUM) NUM from  " + RetSqlTab("SC7")
				 	cQuery += " where SC7.C7_FILIAL = '" + cFilAnt + "' "
					OPENSQL(_cAlias, cQuery)
				
				 	If (_cAlias)->( ! EoF() )
				 		cNum := Soma1((_cAlias)->NUM)
				 		dbSelectArea("SC7")
				 		dbSetOrder(1)
				 		While dbSeek(xFilial("SC7")+cNum )
				 			cNum := Soma1(cNum)
						EndDo
				 	EndIf
				 	CLOSESQL(_cAlias)
				Else
					cNum := Soma1(cNum)
			 	EndIf*/
		 	
			 	dbSelectArea("SA2")
				dbSetOrder(3)  //A2_FILIAL+A2_CGC
				dbSeek(xFilial('SA2')+PADR(aProposta[nZ]:csCdEmpresa, Len(SA2->A2_CGC)))
				
				aAdd(aMt120Cb, {"C7_NUM"    , cNum})
				aAdd(aMt120Cb, {"C7_EMISSAO", Date() })
				aAdd(aMt120Cb, {"C7_FORNECE", SA2->A2_COD						  }) //"000001"})
				aAdd(aMt120Cb, {"C7_LOJA"   , SA2->A2_LOJA						  }) //"01"})
				aAdd(aMt120Cb, {"C7_COND"   , aProposta[nZ]:csCdCondicaoPagamento }) //"001"})
				aAdd(aMt120Cb, {"C7_CONTATO", oWSParCotacaoDTO:csCdUsuario    	  }) //"AUTO"})
				aAdd(aMt120Cb, {"C7_FILENT" , cFilEnt							  })
				aAdd(aMt120Cb, {"C7_TPFRETE", aProposta[nZ]:csCdFrete			  })
				aAdd(aMt120Cb, {"C7_MOEDA"  , Val(aProposta[nZ]:csCdMoedaProposta)})
				aAdd(aMt120Cb, {"C7_TXMOEDA", RecMoeda(Date(), Val(aProposta[nZ]:csCdMoedaProposta)) })
				aAdd(aMt120Cb, {"C7_USER"   , __cUserID						      })
				
				aAdd( aPedido, { cAux, cNum, cOrigem, cDifere, aMt120Cb })			
			EndIf
			//For nX := 1 To Len(aItens)
			If (nPos := aScan( aPedido, { |x| x[1] == cAux } )) > 0
				aLinha := {}
				
				cAliCo:= GetNextAlias()
				cQuery := " select C8_NUM NUM from  " + RetSqlTab("SC8")
			 	cQuery += " where D_E_L_E_T_ = ' ' "
			 	cQuery += "   and C8_XCODPAR = '" + oWSParCotacaoDTO:csCdCotacaoWbc + "' "
			 	cQuery += "   and C8_XITEPAR = '" + aItens[nX]:csCdItemWbc + "' "
			 	cQuery += "   and C8_XNPROPA = '" + cValToChar(aProposta[nZ]:nnCdProposta) + "' "
			 	cQuery += "   and C8_XCOTACA = '" + oWSParCotacaoDTO:csCdCotacaoERP + "' "
			 	
			 	OPENSQL(cAliCo, cQuery)
				dbSelectArea(cAliCo)
			 	If (cAliCo)->( ! EoF() )
			 		cNumCot := (cAliCo)->NUM
			 	Else
			 		cNumCot := ''
			 	EndIf
			 	
			 	Conout("Pega Cotacao do PC -> "+cNumCot)
			 	
			 	CLOSESQL(cAliCo)
			 	
				If Len(aPedido[nPos]) < 6
		 			cItem := StrZero(1, tamsx3("C7_ITEM")[1])
		 		Else
		 			cItem := StrZero((Len(aPedido[nPos][6]) + 1), tamsx3("C7_ITEM")[1])
		 		EndIf
				aAdd(aLinha, {"C7_ITEM"   , cItem	                          					 , Nil})
				aAdd(aLinha, {"C7_PRODUTO", aItens[nX]:csCdProduto								 , Nil})
				aAdd(aLinha, {"C7_QUANT"  , aPropEnd[1]:ndQtFornecimento	 					 , Nil})
				aAdd(aLinha, {"C7_PRECO"  , aProposta[nZ]:ndVlLiquido							 , Nil}) //ndVlUnitario
				//aAdd(aLinha, {"C7_TES"  , "001" 												 , Nil})
				aAdd(aLinha, {"C7_DESC"   , aProposta[nZ]:ndPcDesconto            				 , Nil})
				aAdd(aLinha, {"C7_DATPRF" , StoD(Left(StrTran(aPropEnd[1]:ctDtFornecimento, "-",""), 8)), Nil}) //complementar data de entrega com informa??o.
				aAdd(aLinha, {"C7_NUMCOT" , cNumCot	   	                       , Nil})
				
				aAdd(aLinha, {"C7_XITWBC" , aItens[nX]:csCdItemWbc 			   , Nil})
				aAdd(aLinha, {"C7_XINTPA" , '2'                                , Nil})
				aAdd(aLinha, {"C7_XPEDWBC", cPedWS                             , Nil})
				aAdd(aLinha, {"C7_XTPORIG", 2	                               , Nil}) // 1-leilao 2-cotacao 3-contrato
				aAdd(aLinha, {"C7_XPROPOS", aProposta[nZ]:nnCdProposta         , Nil})
				aAdd(aLinha, {"C7_XCOTACA", oWSParCotacaoDTO:csCdCotacaoERP    , Nil})
	
				dbSelectArea("SC1")
				dbSetOrder(2)
				If dbSeek(xFilial('SC1')+PADR(aItens[nX]:csCdProduto,Len(SC7->C7_PRODUTO))+PADR(cNumSC,Len(SC7->C7_NUMSC))+PADR(aEndereco[1]:csCdItemRequisicaoEmpresa,Len(SC7->C7_ITEMSC)))
					aAdd(aLinha, {"C7_OBS"    , SC1->C1_OBS  	      				  , Nil})
					aAdd(aLinha, {"C7_LOCAL"  , SC1->C1_LOCAL						  , Nil})
					aAdd(aLinha, {"C7_NUMSC"  , cNumSC    							  , Nil})
					aAdd(aLinha, {"C7_ITEMSC" , aEndereco[1]:csCdItemRequisicaoEmpresa, Nil})
					aAdd(aLinha, {"C7_RATEIO"  , SC1->C1_RATEIO                                   , Nil})
					If SC1->C1_RATEIO == "2"
					  aAdd(aLinha, {"C7_CC"     , SC1->C1_CC	                          , Nil})
					  aAdd(aLinha, {"C7_CONTA"  , SC1->C1_CONTA                         , Nil})
					  aAdd(aLinha, {"C7_ITEMCTA", SC1->C1_ITEMCTA                   , Nil})
					  aAdd(aLinha, {"C7_CLVL"   , SC1->C1_CLVL                          , Nil})
					  aAdd(aLinha, {"C7_EC05DB" , SC1->C1_EC05DB                        , Nil})
				    Endif
				EndIf
				//aAdd(aPedWS, aItens[nX]:csCdItemWbc)
				
			 	For nW := 1 To Len(aTaxa)
					If aTaxa[nW]:nnCdTaxa == 1 //ICMS
	                	AADD(aLinha, {"C7_PICM"    , aTaxa[nW]:ndPcTaxa, Nil})
	                EndIf
	                If aTaxa[nW]:nnCdTaxa == 2 //IPI
	                	AADD(aLinha, {"C7_IPI"     , aTaxa[nW]:ndPcTaxa, Nil})
	                EndIf
	                If aTaxa[nW]:nnCdTaxa == 3 //Redu??o ICMS
	                	AADD(aLinha, {"C7_ICMSRET" , aTaxa[nW]:ndPcTaxa, Nil}) //Round( Round(aItens[nX]:ndVlItem * (IIf(nTipo == 3, aItens[nX]:ndQtItem, aEntrega[nW]:ndQtEntrega)), 2) * (aTaxa[nW]:ndPcTaxa / 100), 2), Nil})
	                EndIf
	                If aTaxa[nW]:nnCdTaxa == 5 //ST
	                	//AADD(aLinha, {"????" , aTaxa[nW]:ndPcTaxa, Nil})
	                EndIf
				Next nW
				dbSelectArea("ZIP")
				For nW := 1 To Len(aTaxa)
					Conout("PAR001 - 2540 Erro ao gravar ZIP "+xFilial('ZIP') +" -"+cValToChar(aProposta[nZ]:nnCdProposta)+" - "+aItens[nX]:csCdItemWbc+" - "+cPedWS+" - "+SC7->C7_ITEM+" "+cValToChar(Len(aTaxa))+" - "+cValToChar(nW))
					If RecLock("ZIP", .T.)
						Conout("PAR001 - 2540 Erro ao gravar ZIP "+xFilial('ZIP') +" -"+cValToChar(aProposta[nZ]:nnCdProposta)+" - "+aItens[nX]:csCdItemWbc+" - "+cPedWS+" - "+SC7->C7_ITEM+" - "+cValToChar(ZIP->(Recno()))+" "+cValToChar(Len(aTaxa))+" - "+cValToChar(nW)) 
						ZIP->ZIP_FILIAL := xFilial('ZIP') 
						ZIP->ZIP_NUM    := cNum
						ZIP->ZIP_ITEM   := SC7->C7_ITEM
						ZIP->ZIP_INCLUS := aTaxa[nW]:nbFlIncluso
						ZIP->ZIP_TAXA   := aTaxa[nW]:ndPcTaxa
						ZIP->ZIP_CODTAX := aTaxa[nW]:nnCdTaxa
						ZIP->ZIP_PEDPAR := cPedWS
						ZIP->ZIP_ITEPAR := aItens[nX]:csCdItemWbc
						ZIP->ZIP_PROPOS := aProposta[nZ]:nnCdProposta
						MsUnLock()
				    EndIf
				Next nW
				
				aAdd(aMt120It,aLinha)
				If Len(aPedido[nPos]) < 6
		 			aAdd(aPedido[nPos], {aLinha})
		 		Else
			 		aAdd( aPedido[nPos][6], aLinha )
		 		EndIf
		 		If Len(aPedido[nPos]) < 7
		 			aAdd(aPedido[nPos], {aItens[nX]:csCdItemWbc})
		 		Else
			 		aAdd( aPedido[nPos][7], aItens[nX]:csCdItemWbc )
		 		EndIf
		 		
		 		aAdd(aPedido[nPos], aItens[nX]:csDsJustificativaERP)
			EndIf
			
			dbSelectArea("SA2")
			dbSetOrder(3)  //A2_FILIAL+A2_CGC
			dbSeek(xFilial('SA2')+PADR(aProposta[nZ]:csCdEmpresa, Len(SA2->A2_CGC)))
				
			//1	A5_FILIAL+A5_FORNECE+A5_LOJA+A5_PRODUTO+A5_FABR+A5_FALOJA	Fornecedor + Loja + Produto + Fabricante + Loja Fabric.
			DbSelectArea('SA5')
			dbSetOrder(1)
			If dbSeek(xFilial('SA5')+SA2->A2_COD+SA2->A2_LOJA+PADR(aItens[nX]:csCdProduto,Len(SA5->A5_PRODUTO)) )
				RecLock('SA5', .F.)
				SA5->A5_CODPRF := aProposta[nZ]:csCdProdutoFornecedor
				//SA5->A5_NCMPRF := aProposta[nZ]:csCdNmb
				MsUnLock()
			Else
				
				oMT061 := FWLoadModel('MATA061')
				
				oMT061:SetOperation(3)
				oMT061:Activate()
				//Cabe?alho
				oMT061:SetValue('MdFieldSA5','A5_PRODUTO', PADR(aItens[nX]:csCdProduto,Len(SA5->A5_PRODUTO)))
				//oMT061:SetValue('MdFieldSA5','A5_NOMPROD', ' ')
				//Grid
				oMT061:SetValue('MdGridSA5','A5_FORNECE', SA2->A2_COD)
				oMT061:SetValue('MdGridSA5','A5_LOJA'   , SA2->A2_LOJA)
				oMT061:SetValue('MdGridSA5','A5_CODPRF' , aProposta[nZ]:csCdProdutoFornecedor)
				//oMT061:SetValue('MdGridSA5','A5_NCMPRF' , aProposta[nZ]:csCdNmb)
				//oMT061:SetValue('MdGridSA5','A5_NOMEFOR', 'FOR. P/ ROTINA MATA061 - CT001')
				
				If oMT061:VldData()
					oMT061:CommitData()
				Else
					aErro := oMT061:GetErrorMessage()
					cErro := ' Erro MATA061 Produto x Fornecedor ' + CRLF
				    //TmsMsgErr(aErro)
				    For nE := 1 To Len(aErro)
				    	cErro += AllToChar(aErro[nE]) + CRLF
				    	Conout(' Erro MATA061')
				    	Conout(AllToChar(aErro[nE]) )
				    Next nE
				    oLog:Retorno   := 0
					oLog:Origem    := cOrigem
					oLog:MsgLog    := cErro
					oLog:SoapFault := cErro
					oLog:Tstamp    := FwTimeStamp(3)
					oLog:Token     := 'MATA061'
					oLog:DIfere    := 'MATA061' + cDifere
					oLog:SalvaObj('SA5')
					oLog:novoLog()
				Endif
				
				oMT061:DeActivate()
				oMT061:Destroy()
			EndIf
		Next nZ
	Next nX
	nX := 0
	For nY := 1 To Len(aPedido)
		lMsErroAuto := .F.
		oLog:Funcao := 'RetornarCotacaoItem'
		nProc++
		If !Empty(NomeAutoLog())
			MemoWrite( NomeAutoLog(), ' ' )
		EndIf
		
		cFilAnt := Separa(aPedido[nY][1], ".", .T.)[4]
		cNum    := aPedido[nY][2]
		cOrigem := aPedido[nY][3]
		cDifere := aPedido[nY][4]
		aPCab   := aPedido[nY][5]
		aPItens := aPedido[nY][6]
		aPedWS  := aPedido[nY][7]
		//MATA120(1,aMt120Cb,aMt120It,3)
		//alert('Criar pedido: ' + cNum + '  filial: ' + cFilAnt)     

		conout('funname -> ' +funname())

		RpcSetType(2) // 2 = Intregra??es/Gestao Hospitalar/Gest?o de Suprimentos, 3 = N?o consome licen?a, 4 = Teste automatizado

		MSExecAuto({|x,y,z| MATA120(1, x, y, z) }, aPCab, aPItens, 3)

		If !lMsErroAuto
			cNum := SC7->C7_NUM
			conout(" Pedido de compra " + cNum + " integrado com sucesso!")
			oLog:Retorno   := 1
			oLog:Origem    := cOrigem
			oLog:MsgLog    := "Pedido de compra " + cNum + " integrado com sucesso!"
			oLog:SoapFault := "Pedido de compra " + cNum + " integrado com sucesso!"
			oLog:Tstamp    := FwTimeStamp(3)
			oLog:Token     := 'MATA120'		
			oLog:DIfere    := cDifere
			oLog:SalvaObj('SC7')
			oLog:novoLog() //SENSUS 25/02/2021
			
			If !Empty(aPedido[nY][8])
				DbSelectArea('SCR')
				cAliaSRC := GetNextAlias()
				cQuery := " SELECT R_E_C_N_O_ REG FROM " + RetSqlTab("SCR")
			 	cQuery += "  WHERE D_E_L_E_T_ = ' ' "
			 	cQuery += "    AND CR_FILIAL  = '" + xFilial('SCR') + "' "
			 	cQuery += "    AND CR_NUM     = '" + cNum + "' "
				OPENSQL(cAliaSRC, cQuery)
				
				DbSelectArea(cAliaSRC)
			 	While (cAliaSRC)->( ! EoF() )
			 		SCR->(DbGoTo((cAliaSRC)->REG))
			 		Reclock("SCR",.F.)
					SCR->CR_OBS := aPedido[nY][8]
					MsUnlock()
			 		(cAliaSRC)->(DbSkip())
			 	EndDo
			 	CLOSESQL(cAliaSRC)
			EndIf
			
			dbSelectArea("SC7")
			dbSetOrder(1)
			dbSeek(xFilial("SC7")+cNum)
			While SC7->(!EoF()) .And. SC7->C7_FILIAL = xFilial('SC7') .And. SC7->C7_NUM = cNum
				cAliCo:= GetNextAlias()
				cQuery := " select R_E_C_N_O_ REG from  " + RetSqlTab("SC8")
			 	cQuery += " where D_E_L_E_T_ = ' ' "
			 	cQuery += "   and C8_XCODPAR = '" + SC7->C7_XPEDWBC + "' "
			 	cQuery += "   and C8_XITEPAR = '" + SC7->C7_XITWBC  + "' "
			 	cQuery += "   and C8_XNPROPA =  " + cValToChar(SC7->C7_XPROPOS)
			 	cQuery += "   and C8_XCOTACA = '" + SC7->C7_XCOTACA + "' "
			 	OPENSQL(cAliCo, cQuery)
				dbSelectArea(cAliCo)
			 	If (cAliCo)->( ! EoF() )
					DbSelectArea('SC8')
					SC8->( DbGoTo( (cAliCo)->REG ) )
					RecLock('SC8', .F.)
					SC8->C8_ALIIPI	:= SC7->C7_IPI		//dPcTaxa		
					SC8->C8_PICM	:= SC7->C7_PICM		//dPcTaxa	
					SC8->C8_NUMPED	:= SC7->C7_NUM		//numero do pedido no protheus
					SC8->C8_ITEMPED	:= SC7->C7_ITEM		//numero do item pedido no protheus
					SC8->C8_VLDESC	:= SC7->C7_VLDESC	//Vl. Desconto		
					SC8->C8_SEGUM	:= SC7->C7_SEGUM	//Segunda UM		
					SC8->C8_QTSEGUM	:= SC7->C7_QTSEGUM	//Qtd. 2a UM	
					SC8->C8_GRUPCOM	:= SC7->C7_GRUPCOM	//Gr. Compras		
					SC8->C8_SEGURO	:= SC7->C7_SEGURO	//Vlr. Seguro		
					SC8->C8_DESPESA	:= SC7->C7_DESPESA	//Vlr. Despesa		
					SC8->C8_VALIPI	:= SC7->C7_VALIPI	//Vlr. IPI	SIM	realizar calculo
					SC8->C8_VALICM	:= SC7->C7_VALICM	//Vlr. ICMS	SIM	realizar calculo
					SC8->C8_BASEICM	:= SC7->C7_BASEICM	//Base de ICMS	SIM	realizar calculo
					SC8->C8_BASEIPI	:= SC7->C7_BASEIPI	//base de IPI	SIM	realizar calculo
					SC8->C8_DESC	:= SC7->C7_DESC		//% Desc. Item	SIM	realizar calculo
					SC8->C8_NUMCON	:= SC7->C7_CONTRA	//Num.Contrato
					MsUnlock()

					//Altera??o para gravar o numero da cota??o no n?mero do pedido
					RecLock('SC7', .F.)
					SC7->C7_NUMCOT := SC8->C8_NUM
					MsUnlock()  
					
					CONOUT("Grava Cotacao no PC -> "+SC7->C7_NUMCOT)
					
					dbSelectArea("SC1")
					dbSetOrder(1)
					If dbSeek(xFilial('SC1')+SC7->C7_NUMSC+SC7->C7_ITEMSC)
						RecLock('SC1', .F.)
						SC1->C1_COTACAO := SC8->C8_NUM
						SC1->C1_QUJE    := SC7->C7_QUANT // Sensus 26/02/2021
						MsUnlock()
					EndIf

				EndIf
			 	CLOSESQL(cAliCo)
			 	
				SC7->(DbSkip())
			EndDo
		Else
			lerro := .T.
			alert(MemoRead(NomeAutoLog()))
			conout(PADR("ERROR - " +PADR(ProcName(1),10) + " - Tempo " +FWTimeStamp(2) +" - ",60) + 'Erro MATA120 ' + IIf(!Empty(NomeAutoLog()),MemoRead(NomeAutoLog()),''))
			oLog:Retorno   := 0
			oLog:Origem    := cOrigem
			oLog:MsgLog    := 'Erro MATA120 ' + IIf(!Empty(NomeAutoLog()),MemoRead(NomeAutoLog()),'')
			oLog:SoapFault := 'Erro MATA120 ' + IIf(!Empty(NomeAutoLog()),MemoRead(NomeAutoLog()),'')
			oLog:Tstamp    := FwTimeStamp(3)
			oLog:Token     := 'MATA120'
			oLog:DIfere    := cDifere
			oLog:SalvaObj('SC7')
			oLog:novoLog()   //Sensus em 25/02/2021
			
			MemoWrite( NomeAutoLog(), ' ' )
		    
		  	fHabiPed(2, cPedWS, aPedWS, oLog)
		EndIf
		//oLog:novoLog() //SENSUS 25/02/2021
	Next nY
	__cUserID := cUserAux
	cFilAnt   := cFilAux
	ErrorBlock(oError)

Return


/*/{Protheus.doc} fCotacao
//Gera o pedido de compras conforme pedido do portal
@author fabricio.reche
@since 23/05/2018
@version 2.0
@param oWSParPedidoDTO, object, objeto de retorno do pedido do portal
@param cNumSC, characters, N?mero da solicita??o de compras
@type function
/*/
Static Function fCotacao(oWSParCotacaoDTO, oLog)
	Local aPropEnd := {}
	Local aTaxa    := {}
	Local aPedido  := {}
	Local aErro    := {}
	Local nX       := 0
	Local nY       := 0
	Local nZ       := 0
	Local nW       := 0
	Local nE	   := 0
	Local nPos     := 0
	Local cNum     := ''
	Local cItem    := ''
	Local cPedWS   := ''
	Local cQuery   := ''
	Local _cAlias  := ''
	Local cOrigem  := ''
	Local cCodUsua := ''
	Local cUsuario := ''
	//Local cUserAux := __cUserID
	Local cDifere  := ''
	Local cFilAux  := cFilAnt
	Local oError   := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'SC8', @oLog, @cPedWS, @nY, @oWSParCotacaoDTO, @cOrigem, @cDifere, @nX)})
	
	Private lMsErroAuto := .F.
	//dbSelectArea("ZPL")
	dbSelectArea("SC8")
	dbSetOrder(1)
	
	oLog:Usuario := oWSParCotacaoDTO:csCdUsuario
	cPedWS  := oWSParCotacaoDTO:csCdCotacaoWbc
	aItens  := oWSParCotacaoDTO:oWSlstCotacaoItemDTO:oWSParCotacaoItemDTO
	cOrigem := oWSParCotacaoDTO:csCdCotacaoERP + ' ' + cPedWS
	
	cUsuario  := PADR(oWSParCotacaoDTO:csCdUsuario, tamsx3("ZUP_NOMRED")[1])
	cCodUsua  := POSICIONE('ZUP', 2, cUsuario, 'ZUP_CODUSU')
	/*cUserAux  := __cUserID
	If !Empty(cCodUsua)
		__cUserID := cCodUsua
	EndIf
	Conout(' Criar SC8. sCdUsuario: ' + oWSParCotacaoDTO:csCdUsuario + ' cCodUsua: ' + cCodUsua + ' cUserAux: ' + cUserAux + ' ')*/
			
	For nX := 1 To Len(aItens)
		If aItens[nX]:nnCdSituacao == 6
			Conout(' :: PARADIGMA :: Cotacao ' + cOrigem  + ' - item ' + aItens[nX]:csCdItemWbc + ' cancelado!')
			Loop
		EndIf
		aEndereco := aItens[nX]:oWSlstCotacaoItemEnderecoDTO:oWSParCotacaoItemEnderecoDTO
		aProposta := aItens[nX]:oWSlstCotacaoPropostaDTO:oWSParCotacaoPropostaDTO
		cOrigem   := oWSParCotacaoDTO:csCdCotacaoERP + ' ' + cPedWS + '-' + aItens[nX]:csCdItemWbc
		If Empty(aEndereco[1]:csCdRequisicaoEmpresa)
			Conout(' :: PARADIGMA :: Cotacao ' + cOrigem + ' sem requisicao!')
			Loop
		EndIf
		aNumSC  := Separa(aEndereco[1]:csCdRequisicaoEmpresa, ".", .T.)
		cFilAnt := aNumSC[1]
		cCgcEnt := IIf(Empty(aEndereco[1]:csCdEntregaEndereco), aEndereco[1]:csCdEmpresaEntregaEndereco, aEndereco[1]:csCdEntregaEndereco)
		nPos    := aScan(aEmpFil, {|x| x[18] == cCgcEnt})
		cFilEnt := aEmpFil[nPos][2]
		
		For nZ := 1 To Len(aProposta)
			dbSelectArea("SA2")
			dbSetOrder(3)  //A2_FILIAL+A2_CGC
			If !dbSeek(xFilial('SA2')+PADR(aProposta[nZ]:csCdEmpresa, Len(SA2->A2_CGC)))
				Conout(' :: PARADIGMA :: Cotacao ' + cOrigem + ' Fornecedor invalido! ' + aProposta[nZ]:csCdEmpresa)
				Loop
			EndIf
			cDifere     := cValToChar(aProposta[nZ]:nnCdProposta)
			cOrigem     := oWSParCotacaoDTO:csCdCotacaoERP + ' ' + cPedWS + '-' + aItens[nX]:csCdItemWbc + ' ' + cDifere
			aPropEnd    := aProposta[nZ]:oWSlstCotacaoPropostaEnderecoDTO:oWSParCotacaoPropostaEnderecoDTO
			aTaxa       := aProposta[nZ]:oWSlstCotacaoPropostaTaxaDTO:oWSParCotacaoPropostaTaxaDTO
			cNumSC      := IIf(Len(aNumSC) == 2 .And. !Empty(aNumSC[2]), aNumSC[2], aNumSC[1])
			
			cAux := aProposta[nZ]:csCdEmpresa + '.' + aProposta[nZ]:csCdCondicaoPagamento + '.' + aProposta[nZ]:csCdFrete + '.' + cFilAnt
		 	If Empty(cNum)
				_cAlias:= GetNextAlias()
				cQuery := " select max(SC8.C8_NUM) NUM from  " + RetSqlTab("SC8")
			 	cQuery += " where SC8.C8_FILIAL = '" + cFilAnt + "' "
				OPENSQL(_cAlias, cQuery)
				DbSelectArea(_cAlias)
			 	If (_cAlias)->( ! EoF() )
			 		cNum := Soma1((_cAlias)->NUM)
			 		dbSelectArea("SC8")
			 		dbSetOrder(1)
			 		While dbSeek(xFilial("SC8")+cNum )
			 			cNum := Soma1(cNum)
					EndDo
			 	EndIf
			 	CLOSESQL(_cAlias)
		 	EndIf
			
			_cAlias:= GetNextAlias()
			cQuery := " select R_E_C_N_O_ REG, C8_NUM NUM from  " + RetSqlTab("SC8")
		 	cQuery += " where D_E_L_E_T_ = ' ' "
		 	cQuery += "   and C8_XCODPAR = '" + oWSParCotacaoDTO:csCdCotacaoWbc + "' "
		 	cQuery += "   and C8_XITEPAR = '" + aItens[nX]:csCdItemWbc + "' "
		 	cQuery += "   and C8_XNPROPA =  " + cValToChar(aProposta[nZ]:nnCdProposta)
		 	cQuery += "   and C8_XCOTACA = '" + oWSParCotacaoDTO:csCdCotacaoERP + "' "
		 	OPENSQL(_cAlias, cQuery)
			dbSelectArea(_cAlias)
		 	If (_cAlias)->( ! EoF() )
		 		SC8->( DbGoTo( (_cAlias)->REG ) )
		 		RecLock('SC8', .F.)
		 	Else
		 		RecLock('SC8', .T.)
		 		SC8->C8_FILIAL  := cFilAnt //SC7->C7_FILIAL
		 		SC8->C8_NUM	    := cNum 	///SC7->C7_XPEDWBC  //sCdCotacaoWbc
		 	EndIf
		 	CLOSESQL(_cAlias)
			
			SC8->C8_ITEM	:= StrZero(nX, tamsx3("C8_ITEM")[1]) //SC7->C7_XITWBC	//sCdItemWbc
			SC8->C8_NUMPRO	:= StrZero(nZ, tamsx3("C8_NUMPRO")[1]) //Right(cValToChar(SC7->C7_XPROPOS), 2)  //C	,2,0,	Proposta		
			SC8->C8_PRODUTO	:= aItens[nX]:csCdProduto 			//SC7->C7_PRODUTO	//sCdProduto
			SC8->C8_UM	    := aItens[nX]:csCdUnidadeMedida 	//SC7->C7_UM		//sCdUnidadeMedida
			SC8->C8_QUANT	:= aPropEnd[1]:ndQtFornecimento		//SC7->C7_QUANT	//dQtItem
			SC8->C8_PRECO	:= aProposta[nZ]:ndVlLiquido		//SC7->C7_PRECO	//dVlProposta
			SC8->C8_TOTAL	:= SC8->C8_QUANT * SC8->C8_PRECO	//SC7->C7_TOTAL	//dQtItem * dVlProposta
			SC8->C8_COND	:= aProposta[nZ]:csCdCondicaoPagamento //SC7->C7_COND		//sCdCondicaoPagamento
			SC8->C8_PRAZO 	:= DateDiffDay( Date(), StoD(Left(StrTran(aProposta[nZ]:ctDtValidade, "-", ""), 8)))	//N	,5,0,	Prazo Entreg	SIM	tDtValidade menos dia atual
			SC8->C8_FORNECE := SA2->A2_COD		//SC7->C7_FORNECE
			SC8->C8_LOJA	:= SA2->A2_LOJA		//SC7->C7_LOJA     //C	,2,0,	Loja				
			SC8->C8_FORNOME	:= SA2->A2_NOME		//Nome	N?O	N?O TEM
			SC8->C8_FORMAIL	:= SA2->A2_XEMAIL	//E-mail
			SC8->C8_CONTATO	:= oWSParCotacaoDTO:csCdUsuario		//SC7->C7_CONTATO
			SC8->C8_FILENT	:= cFilEnt							//SC7->C7_FILENT	//Filial Entr.	SIM	sCdEntregaEndereco
			SC8->C8_EMISSAO	:= Date() //SC7->C7_EMISSAO	//tDtProposta
			SC8->C8_TPFRETE	:= aProposta[nZ]:csCdFrete			//SC7->C7_TPFRETE	//sCdFrete
			SC8->C8_VALIDA	:= StoD(Left(StrTran(aProposta[nZ]:ctDtValidade, "-", ""), 8)) 	//tDtValidade
			SC8->C8_NUMSC	:= cNumSC			//SC7->C7_NUMSC	//sCdRequisicaoEmpresa
			SC8->C8_ITEMSC	:= aEndereco[1]:csCdItemRequisicaoEmpresa	//SC7->C7_ITEMSC	//sCdItemRequisicaoEmpresa
			SC8->C8_DATPRF	:= StoD(Left(StrTran(aPropEnd[1]:ctDtFornecimento, "-",""), 8))	//SC7->C7_DATPRF 	//Necessidade		
		    SC8->C8_IDENT	:= StrZero(nX, tamsx3("C8_IDENT")[1]) //SC7->C7_XITWBC	//sCdItemWbc
			SC8->C8_DESC	:= aProposta[nZ]:ndPcDesconto	//SC7->C7_DESC		//% Desc. Item	SIM	realizar calculo	
			SC8->C8_MOEDA	:= Val(aProposta[nZ]:csCdMoedaProposta)	//SC7->C7_MOEDA	//sCdMoeda
			SC8->C8_TXMOEDA	:= RecMoeda(Date(), Val(aProposta[nZ]:csCdMoedaProposta)) //SC7->C7_TXMOEDA	//Taxa Moeda
			SC8->C8_OBS		:= aProposta[nZ]:csDsObservacao	//SC7->C7_OBS		//Observacoes			
			SC8->C8_BASEICM	:= SC8->C8_TOTAL	//SC7->C7_BASEICM	//Base de ICMS	SIM	realizar calculo
			SC8->C8_BASEIPI	:= SC8->C8_TOTAL	//SC7->C7_BASEIPI	//base de IPI	SIM	realizar calculo
			SC8->C8_XCODPAR := oWSParCotacaoDTO:csCdCotacaoWbc
			SC8->C8_XITEPAR := aItens[nX]:csCdItemWbc
			SC8->C8_XNPROPA := aProposta[nZ]:nnCdProposta
			SC8->C8_XCOTACA := oWSParCotacaoDTO:csCdCotacaoERP
			For nW := 1 To Len(aTaxa)
				If aTaxa[nW]:nnCdTaxa == 1 //ICMS
                	SC8->C8_PICM	:= aTaxa[nW]:ndPcTaxa	//SC7->C7_PICM		//dPcTaxa
                	SC8->C8_VALICM	:= (SC8->C8_PICM * SC8->C8_BASEICM) / 100	//SC7->C7_VALICM	//Vlr. ICMS	SIM	realizar calculo
                EndIf
                If aTaxa[nW]:nnCdTaxa == 2 //IPI
                	SC8->C8_ALIIPI	:= aTaxa[nW]:ndPcTaxa	//SC7->C7_IPI		//dPcTaxa
                	SC8->C8_VALIPI	:= (SC8->C8_ALIIPI * SC8->C8_BASEIPI) / 100	//SC7->C7_VALIPI	//Vlr. IPI	SIM	realizar calculo
                EndIf
			Next nW			
			//SC8->C8_NUMPED	:= SC7->C7_NUM		//numero do pedido no protheus
			//SC8->C8_ITEMPED	:= SC7->C7_ITEM		//numero do item pedido no protheus
			//SC8->C8_NUMCON	:= SC7->C7_CONTRA	//Num.Contrato
			//SC8->C8_VLDESC	:= SC7->C7_VLDESC	//Vl. Desconto		
			//SC8->C8_SEGUM		:= SC7->C7_SEGUM	//Segunda UM		
			//SC8->C8_QTSEGUM	:= SC7->C7_QTSEGUM	//Qtd. 2a UM	
			//SC8->C8_GRUPCOM	:= SC7->C7_GRUPCOM	//Gr. Compras		
			/*SC8->C8_SEGURO	:= SC7->C7_SEGURO	//Vlr. Seguro		
			SC8->C8_DESPESA	:= SC7->C7_DESPESA	//Vlr. Despesa	
			SC8	9	C8_QTDCTR	N	,18,5,	Qtd.p/ Ctr.		
			SC8	12	C8_CODTAB	C	,3,0,	Tab.Preco		
			SC8	14	C8_TAXAFIN	N	,9,4,	Taxa Financ.
			Virtual SC8->C8_DESCRI	:= SC7->C7_DESCRI   //sDsItem
			SC8	22	C8_TES	C	,3,0,	Tipo Entrada
			SC8	24	C8_VALFRE	N	,14,2,	Vlr.Frete		
			SC8	25	C8_VALEMB	N	,14,2,	Vlr.Embal.		
			SC8->C8_DESC1	:= SC7->C7_DESC		//dPcDesconto
			SC8	27	C8_DESC2	N	,5,2,	Desconto 2		
			SC8	28	C8_DESC3	N	,5,2,	Desconto 3	
			SC8	30	C8_TOTFRE	N	,14,2,	Frete Total		
			SC8	31	C8_AVISTA	N	,14,2,	Prc a Vista		
			SC8	32	C8_REAJUST	C	,3,0,	Reajuste		
			SC8	33	C8_DTVISTA	D	,8,0,	DT Prc.Vista
			SC8	40	C8_IDENT	C	,4,0,	Identif.		
			SC8	44	C8_MOTIVO	C	,30,0,	Motivo		
			SC8	46	C8_STATME	C	,1,0,	Status do ME		
			SC8	47	C8_OK	    C	,2,0,	Ok		
			SC8	55	C8_MSG	C	,3,0,	Mensagem	
			SC8	58	C8_ORCFOR	C	,20,0,	Nr.Or?amento		
			SC8	59	C8_SEQFOR	C	,10,0,	Sq.Or?amento		
			SC8	60	C8_ITEFOR	C	,10,0,	It.Or?amento		
			SC8	61	C8_CODGRP	C	,4,0,	Grupo		
			SC8	62	C8_CODITE	C	,27,0,	Cod. Produto		
			SC8	63	C8_ITEMGRD	C	,3,0,	Item Grade		
			SC8	64	C8_ITSCGRD	C	,3,0,	Grade SC		
			SC8	65	C8_GRADE	C	,1,0,	Grade		
			SC8	66	C8_CODORCA	C	,8,0,	Cod. Orcam.		
			SC8	67	C8_TPDOC	C	,1,0,	Tp. Doc.		
			SC8	68	C8_INTCLIC	C	,1,0,	ClicBusiness		
			SC8	69	C8_ORIGEM	C	,8,0,	Rotina Gerad		
			SC8	72	C8_WF		L	,1,0,	WF
			SC8	75	C8_ACCNUM	C	,50,0,	Cot. ACC
			SC8	76	C8_ACCITEM	C	,50,0,	Item ACC		
			SC8	77	C8_BASESOL	N	,14,2,	Bs. ICMS Sol		
			SC8	78	C8_VALSOL	N	,14,2,	Val ICMS Sol		
			SC8	79	C8_PRECOOR	N	,18,5,	Prc Estimado		
			SC8	80	C8_NUMPR	C	,15,0,	Nr. Processo		
			SC8	81	C8_CODED	C	,15,0,	Cod. Edital		
			SC8	82	C8_TAXAFOR	N	,11,4,	Taxa Fornece		
			SC8	83	C8_XCOMPR	C	,3,0,	Comprador*/
			MsUnlock()
			
		Next nZ
	Next nX
	
	//__cUserID := cUserAux
	cFilAnt   := cFilAux
	ErrorBlock(oError)

Return

/*/{Protheus.doc} nPCCancel
//Integra os cancelamentos da paradigma
@author fabricio.reche
@since 02/05/2018
@version 1.0
@param oProcess, object, objeto tNewProcess
@type function
/*/
Static Function nPCCancel(oProcess)
	Local oLog     := FwParLog():New("PAR001", "ProcessarPedidoCancelamento")
	Local oWsPc    := Nil
	Local oPed     := Nil
	Local oPcEn    := Nil
	Local oPcTx    := Nil
	Local cQuery   := ''
	Local cFilCGC  := ''
	Local cNum     := ''
	Local aReg     := {}
	Local aPedidos := {}
	Local _cAlias  := GetNextAlias()
	Local nX       := 0
	Local nPos     := 0
	Local nProc    := 0
	Local cFilAux  := cFilAnt
	Local oError   := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'SC7', @oLog, @cNum)})
	
	fIniLog("Cancelamento de Pedido de Compras")

 	SetRegua2(oProcess, 0)
 	IncRegua2(oProcess, "Cancelamento Pedido de Compras")

 	cQuery := " select  R_E_C_N_O_ REG, C7_FILIAL, C7_NUM "
 	cQuery += " from  " + RetSqlTab("SC7")
 	cQuery += " where D_E_L_E_T_ = '*' "
 	//cQuery += "   and C7_CONAPRO  <> 'B' " //liberados
 	cQuery += "   and C7_XINTPA    = '4' "

 	OPENSQL(_cAlias, cQuery)
 	(_cAlias)->( DbEval({|| aAdd(aReg, REG) }) )
 	(_cAlias)->( DbEval({|| aAdd(aPedidos, (C7_FILIAL + C7_NUM)) }, {|| aScan(aPedidos, (C7_FILIAL + C7_NUM)) == 0}) )
 	CLOSESQL(_cAlias)
	
	conout(' ' + cValToChar(len(aPedidos)) + ' Pedidos' )
	
	SetRegua2(oProcess,  Len(aReg) )
	
	
 	For nX := 1 To Len(aPedidos)
 		cNum    := Right(aPedidos[nX], 6)
 		cFilAnt := Left(aPedidos[nX], 5)
 		nPos    := aScan(aEmpFil, {|x| x[2] == cFilAnt})
		cFilCGC := aEmpFil[nPos][18]
		
 		oWsPc   := WSParPedido():New()
 		oWsPc:oWSlstPedidoAtualizarDTO := Pedido_ArrayOfPedidoAtualizarDTO():New()
 		oPed := Pedido_PedidoAtualizarDTO():New()
 		oPed:nnCdSituacao  := 4
 		oPed:csCdComprador := cFilCGC
 		oPed:csCdPedidoErp := cFilAnt + '.' + cNum
 		
 		aAdd(oWsPc:oWSlstPedidoAtualizarDTO:oWSParPedidoAtualizarDTO, oPed:Clone())
 		
		If oWsPc:ProcessarPedidoCancelamento()
			fLogRetWs( oWsPc:oWSProcessarPedidoCancelamentoResult:oWSlstWbtLogDTO:oWSWbtLogDTO, oLog, "SC7", aPedidos[nX], @nProc, .T. )
		Else
			fSoapFault(oLog)
		EndIf
	Next nX
	
	cFilAnt := cFilAux 
	fFimLog("Cancelamento de Pedido de Compras - " + cValToChar(nProc) + ' processados - ' + Time())

Return nProc

/*/{Protheus.doc} nCancelPC
//Integra os cancelamentos da paradigma
@author fabricio.reche
@since 02/05/2018
@version 1.0
@param oProcess, object, objeto tNewProcess
@type function
/*/
Static Function nCancelPC(oProcess)
	Local oLog   := FwParLog():New("PAR001", "RetornarPedidoCancelamento")
	Local oWsPc  := WSParPedido():New()
	Local nProc := 0
	
	fIniLog("Cancelamento de Pedido de Compras")

	If oWsPc:RetornarPedidoCancelamento()
		cancelPC(oWsPc:oWSRetornarPedidoCancelamentoResult:oWSParPedidoAtualizarDTO, oLog, @nProc)
	Else
		fSoapFault(oLog)
	EndIf

	fFimLog("Cancelamento de Pedido de Compras - " + cValToChar(nProc) + ' processados - ' + Time())

Return nProc

/////////////////////////////////////////////////////////
// *************************************************** //
/////////////////////////////////////////////////////////
Static Function cancelPC(oWSParPedidoAtualizarDTO, oLog, nProc)
	Local aMt120Cb := {}
	Local aMt120It := {}
	Local aMata120 := {}
	Local nX       := 0
	Local nPos 	   := 0
	Local oCancel  := Nil
	Local cFilAux  := cFilAnt
	Local cNum     := ''
	Local oError   := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'SC7', @oLog, @cNum)})
	Local aEmpFil  := FWLoadSM0()
	Local cUserAux := __cUserID
	
	Private lMsErroAuto := .F.
	
	Begin Sequence
	For nX := 1 To Len(oWSParPedidoAtualizarDTO)
		lMsErroAuto := .F.
		aMt120Cb    := {}
		aMt120It    := {}
		aMata120    := {}
		nPos      	:= aScan(aEmpFil, {|x| x[18] == oWSParPedidoAtualizarDTO[nX]:csCdComprador})
		cFilAnt   	:= aEmpFil[nPos][2]
		aNum        := Separa(oWSParPedidoAtualizarDTO[nX]:csCdPedidoErp, '.', .T.)
		cNum        := IIf(Len(aNum) == 2 .And. !Empty(aNum[2]), aNum[2], aNum[1])
		
		dbSelectArea("SC7")
		dbSetOrder(1)
		dbSeek(xFilial("SC7")+cNum)
		If SC7->(!EoF())
			__cUserID := SC7->C7_USER
			aAdd(aMt120Cb,{"C7_NUM" 		,SC7->C7_NUM})
			aAdd(aMt120Cb,{"C7_FILIAL" 		,SC7->C7_FILIAL})
			aAdd(aMt120Cb,{"C7_EMISSAO" 	,SC7->C7_EMISSAO})
			aAdd(aMt120Cb,{"C7_FORNECE" 	,SC7->C7_FORNECE})
			aAdd(aMt120Cb,{"C7_LOJA" 		,SC7->C7_LOJA})
			aAdd(aMt120Cb,{"C7_COND" 		,SC7->C7_COND})
			aAdd(aMt120Cb,{"C7_CONTATO" 	,SC7->C7_CONTATO})
			aAdd(aMt120Cb,{"C7_FILENT" 		,SC7->C7_FILENT})
		EndIf
		While SC7->(!EoF()) .And. SC7->C7_FILIAL = xFilial('SC7') .And. SC7->C7_NUM = cNum
			aMata120 := {}
			aAdd(aMata120,{"C7_ITEM"		,SC7->C7_ITEM	,Nil})
			aAdd(aMata120,{"C7_PRODUTO"		,SC7->C7_PRODUTO,Nil})
			aAdd(aMata120,{"C7_QUANT"		,SC7->C7_QUANT	,Nil})
			aAdd(aMata120,{"C7_PRECO"		,SC7->C7_PRECO	,Nil})
			aAdd(aMata120,{"C7_TOTAL"		,SC7->C7_TOTAL	,Nil})  
			aAdd(aMata120,{"C7_NUMCOT"		,""         	,Nil}) //SENSUS 23/02/2021 
			//c7_numcot = c8_num 
			
			aAdd(aMt120It, aClone(aMata120))
	
			SC7->(DbSkip())
		EndDo
		
		nProc++
		If !Empty(NomeAutoLog())
			MemoWrite( NomeAutoLog(), ' ' )
		EndIf
		
		//MATA120(1, aMt120Cb, aMt120It, 5)
		MSExecAuto({|x,y,z| MATA120(1, x, y, z) }, aMt120Cb, aMt120It, 5)
	
		If !lMsErroAuto
			conout("Pedido " + oWSParPedidoAtualizarDTO[nX]:csCdPedidoErp + " Excluido Com Sucesso!")
			oLog:Retorno   := 1
			oLog:Origem    := oWSParPedidoAtualizarDTO[nX]:csCdPedidoErp
			oLog:MsgLog    := "Pedido de compra " + oWSParPedidoAtualizarDTO[nX]:csCdPedidoErp + " Excluido com sucesso!"
			oLog:SoapFault := "Pedido de compra " + oWSParPedidoAtualizarDTO[nX]:csCdPedidoErp + " Excluido com sucesso!"
			oLog:Tstamp    := FwTimeStamp(3)
			oLog:Token     := 'MATA120'		
			oLog:SalvaObj('SC7')
		Else
			lerro := .T.
			conout(PADR("ERROR - " +PADR(ProcName(1),10) + " - Tempo " +FWTimeStamp(2) +" - ",60) + 'Erro MATA120 ' + IIf(!Empty(NomeAutoLog()),MemoRead(NomeAutoLog()),''))
			oLog:Retorno   := 0
			oLog:Origem    := oWSParPedidoAtualizarDTO[nX]:csCdPedidoErp
			oLog:MsgLog    := 'Erro MATA120 ' + IIf(!Empty(NomeAutoLog()),MemoRead(NomeAutoLog()),'')
			oLog:SoapFault := 'Erro MATA120 ' + IIf(!Empty(NomeAutoLog()),MemoRead(NomeAutoLog()),'')
			oLog:Tstamp    := FwTimeStamp(3)
			oLog:Token     := 'MATA120'		
			oLog:SalvaObj('SC7')
			
			MemoWrite( NomeAutoLog(), ' ' )
			
			oCancel := WSParPedido():New()
			/*oCa     := Pedido_PedidoAtualizarDTO():New()			
			oCa:nnCdSituacao  := 4
			oCa:csCdComprador := cFilAnt
			oCa:csCdPedidoErp := oWSParPedidoAtualizarDTO[nX]:csCdPedidoErp*/
			
			aAdd(oCancel:oWSlstPedidoAtualizarDTO:oWSParPedidoAtualizarDTO, oWSParPedidoAtualizarDTO[nX]:Clone())
			
			oLog:novoLog()
			oLog:Funcao := 'HabilitarRetornarPedidoCancelamento'
			If !oCancel:HabilitarRetornarPedidoCancelamento()
				fSoapFault(oLog)
				conout(PADR("Thread - "+cValToChar(ThreadID()) +" - " +PADR(ProcName(1),10) + " - Tempo " +FWTimeStamp(2) +" - ",60) + 'Erro no HabilitarRetornarPedidoCancelamento()')
			EndIf
		EndIf
		oLog:novoLog()
	Next nX
	
	__cUserID := cUserAux
	cFilAnt   := cFilAux
	End Sequence
	ErrorBlock(oError)
Return


/*/{Protheus.doc} fContrato
//Gera o Contrato conforme contrato do portal
@author Administrator
@since 17/08/2018
@version 2.0
@param oWSContratoDTO, object, objeto de retorno do contrato do portal
@type function
/*/
Static Function fContrato(oWSContratoDTO, oLog, nProc)
	Local aMt125Cb := {}
	Local aMt125It := {}
	Local aMata125 := {}
	Local aEntrega := {}
	Local aTaxa    := {}
	Local aItens   := {}
	Local aPedWS   := {}
	Local aPedido  := {}
	Local aErro    := {}
	Local xRetorno
	Local nX       := 0
	Local nY       := 0
	Local nZ       := 0
	Local nE       := 0
	Local nW	   := 0
	Local nPos     := 0
	Local cNum     := ''
	Local cItem    := ''
	Local cPedWS   := ''
	Local cOrigem  := ''
	Local cAliCo   := ''
	Local cUserAux := ''
	Local cCodUsua := ''
	Local cUsuario := ''
	Local cFilAux  := cFilAnt
	Local oError   := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'CN9', @oLog, @cPedWS, @nY, @oWSContratoDTO, @cOrigem)})
	
	Private lMsErroAuto := .F.
	
	Begin Sequence
	oLog:Usuario := oWSContratoDTO:csCdUsuario
	cPedWS   := oWSContratoDTO:csCdCotacaoWbc
	aItens   := oWSContratoDTO:oWSlstCotacaoItemDTO:oWSParCotacaoItemDTO
	cOrigem  := oWSContratoDTO:csCdCotacaoERP + ' ' + cPedWS
	cUsuario := PADR(oWSContratoDTO:csCdUsuario, tamsx3("ZUP_NOMRED")[1])
	cCodUsua := POSICIONE('ZUP', 2, cUsuario, 'ZUP_CODUSU')
	cUserAux := __cUserID
	If !Empty(cCodUsua)
		__cUserID := cCodUsua
	EndIf
	Conout(' Criar contrato _  sCdUsuario: ' + oWSContratoDTO:csCdUsuario + ' cCodUsua: ' + cCodUsua + ' cUserAux: ' + cUserAux + ' ')
		
	For nX := 1 To Len(aItens)
		aEndereco := aItens[nX]:oWSlstCotacaoItemEnderecoDTO:oWSParCotacaoItemEnderecoDTO
		aProposta := aItens[nX]:oWSlstCotacaoPropostaDTO:oWSParCotacaoPropostaDTO
		If Empty(aEndereco[1]:csCdRequisicaoEmpresa)
			Conout(' :: PARADIGMA :: Cotacao ' + cOrigem + ' sem requisicao!')
			Loop
		EndIf
		//nPos  := aScan(aEmpFil, {|x| x[18] == aEndereco[1]:csCdEntregaEndereco})
		cFilAnt := Separa(aEndereco[1]:csCdRequisicaoEmpresa, ".", .T.)[1]
		
		For nZ := 1 To Len(aProposta)
			If aProposta[nZ]:nnIdVencedor == 0
				Loop
			EndIf
			cDifere := '' //cValToChar(aProposta[nZ]:nnCdProposta)
			cOrigem      := oWSContratoDTO:csCdCotacaoERP + ' ' + cPedWS   //+ '-' + aItens[nX]:csCdItemWbc + ' ' + cDifere
			
			cAlias := GetNextAlias()
			cQuery := " select CNB_CONTRA NUM from  " + RetSqlTab("CNB")
		 	cQuery += " where D_E_L_E_T_ = ' ' "
		 	cQuery += "   and CNB_XPEDWB = '" + cPedWS + "' "
		 	cQuery += "   and CNB_XITWBC = '" + aItens[nX]:csCdItemWbc + "' "
		 	cQuery += "   and CNB_XCOTAC = '" + oWSContratoDTO:csCdCotacaoERP + "' "
		 	cQuery += "   and CNB_XPROPO = "  + cValToChar(aProposta[nZ]:nnCdProposta)
			OPENSQL(cAlias, cQuery)
			dbSelectArea(cAlias)
		 	If (cAlias)->( ! EoF() )
		 		cErro := 'Ja existe o contrato ' + (cAlias)->NUM + ' com a proposta ' + cValToChar(aProposta[nZ]:nnCdProposta) + ', cotacao ' + oWSContratoDTO:csCdCotacaoERP
		 		Conout(cErro)
		 		oLog:Retorno   := 0
				oLog:Origem    := cOrigem
				oLog:MsgLog    := 'Erro: ' + cErro
				oLog:SoapFault := 'Erro: ' + cErro
				oLog:Tstamp    := FwTimeStamp(3)
				oLog:Token     := 'Gera Contrato'
				oLog:DIfere    := cDifere
				oLog:SalvaObj('CNB')
				oLog:novoLog()
		 		//lProblem := .T.
		 		CLOSESQL(cAlias)
		 		Loop		 		
		 	EndIf
		 	CLOSESQL(cAlias)
			
			cAux := aProposta[nZ]:csCdEmpresa + '.' + aProposta[nZ]:csCdCondicaoPagamento + '.' + cFilAnt
		 	If aScan( aPedido, { |x| x[1] == cAux }) == 0
		 		aAdd( aPedido, {cAux})
		 		cOrigem := oWSContratoDTO:csCdCotacaoERP + ' ' + cPedWS + '-' + aItens[nX]:csCdItemWbc
		    EndIf
		    If (nPos := aScan( aPedido, { |x| x[1] == cAux } )) > 0
		    	If Len(aPedido[nPos]) < 2
		 			aAdd(aPedido[nPos], {aItens[nX]})
		 		Else
			 		aAdd( aPedido[nPos][2], aItens[nX] )
		 		EndIf
		 	EndIf
		 	
		Next nZ
	Next nX
	
	nX := 0
	nZ := 0
	aItens := {}
	For nY := 1 To Len(aPedido)
		aPedWS      := {}
		aItens 		:= aPedido[nY][2]
		nVlTotal	:= 0
		lCab   		:= .F.
		lProblem    := .F.
		lMsErroAuto := .F.
		oLog:Funcao := "RetornarCotacaoItem"
		cOrigem     := oWSContratoDTO:csCdCotacaoERP + ' ' + cPedWS
		
		For nX := 1 To Len(aItens)
			aEndereco := aItens[nX]:oWSlstCotacaoItemEnderecoDTO:oWSParCotacaoItemEnderecoDTO
			aProposta := aItens[nX]:oWSlstCotacaoPropostaDTO:oWSParCotacaoPropostaDTO
			If nX == 1
				cOrigem := oWSContratoDTO:csCdCotacaoERP + ' ' + cPedWS + '-' + aItens[nX]:csCdItemWbc
			EndIf
			If Empty(aEndereco[1]:csCdRequisicaoEmpresa)
				Conout(' :: PARADIGMA :: Cotacao ' + cOrigem + ' sem requisicao!')
				Loop
			EndIf
			//nPos  := aScan(aEmpFil, {|x| x[18] == aEndereco[1]:csCdEntregaEndereco})
			cFilAnt := Separa(aEndereco[1]:csCdRequisicaoEmpresa, ".", .T.)[1]
			
			aAdd(aPedWS, aItens[nX]:csCdItemWbc)
			
			For nZ := 1 To Len(aProposta)
				If aProposta[nZ]:nnIdVencedor == 0
					Loop
				EndIf
				aPropEnd    := aProposta[nZ]:oWSlstCotacaoPropostaEnderecoDTO:oWSParCotacaoPropostaEnderecoDTO
				aTaxa       := aProposta[nZ]:oWSlstCotacaoPropostaTaxaDTO:oWSParCotacaoPropostaTaxaDTO
				
				If !lCab
					cAlias := GetNextAlias()
					cQuery := " select max(CN9.CN9_NUMERO) NUM from  " + RetSqlTab("CN9")
				 	cQuery += " where CN9_FILIAL = '" + cFilAnt + "' "
					OPENSQL(cAlias, cQuery)
					dbSelectArea(cAlias)
				 	If (cAlias)->( ! EoF() )
				 		cNum := Soma1((cAlias)->NUM)
				 		dbSelectArea("CN9")
				 		dbSetOrder(1)
				 		While dbSeek(xFilial("CN9")+cNum )
				 			cNum := Soma1(cNum)
						EndDo
				 	EndIf
				 	CLOSESQL(cAlias)
				 	
				 	cAliCo := GetNextAlias()
					cQuery := " select C8_NUM NUM from  " + RetSqlTab("SC8")
				 	cQuery += " where D_E_L_E_T_ = ' ' "
				 	cQuery += "   and C8_XCODPAR = '" + oWSContratoDTO:csCdCotacaoWbc + "' "
				 	cQuery += "   and C8_XITEPAR = '" + aItens[nX]:csCdItemWbc + "' "
				 	cQuery += "   and C8_XNPROPA = '" + cValToChar(aProposta[nZ]:nnCdProposta) + "' "
				 	cQuery += "   and C8_XCOTACA = '" + oWSContratoDTO:csCdCotacaoERP + "' "
				 	OPENSQL(cAliCo, cQuery)
					dbSelectArea(cAliCo)
				 	If (cAliCo)->( ! EoF() )
				 		cNumCot := (cAliCo)->NUM
				 	Else
				 		cNumCot := ''
				 	EndIf
				 	CLOSESQL(cAliCo)
				 	
					oModel := FWLoadModel("CNTA300") //Carrega o modelo
			 
					oModel:SetOperation(MODEL_OPERATION_INSERT) // Seta operacao de inclusao
					 
					lRet := oModel:Activate() // Ativa o Modelo
					         
					//SENSUS 03/03/2021
				    aNumSC := Separa(aEndereco[1]:csCdRequisicaoEmpresa, ".", .T.)
				    cNumSC := IIf(Len(aNumSC) == 2 .And. !Empty(aNumSC[2]), aNumSC[2], aNumSC[1])
				
				    dbSelectArea("SC1")
				    dbSetOrder(1)
				    dbSeek(xFilial('SC1')+cNumSC,Len(SC1->C1_NUM))
				
					//Cabe?alho do contrato 
					lRet := oModel:SetValue( 'CN9MASTER', 'CN9_FILIAL'  , SC1->C1_FILENT) //Sensus 03/03/2021
					lRet := oModel:SetValue( 'CN9MASTER', 'CN9_TPCTO'   , '001') //013
					lRet := oModel:SetValue( 'CN9MASTER', 'CN9_NUMERO'  , cNum )
					lRet := oModel:SetValue( 'CN9MASTER', 'CN9_ESPCTR'  , '1'  )
					lRet := oModel:SetValue( 'CN9MASTER', 'CN9_DTINIC'  , StoD(Left(StrTran(oWSContratoDTO:ctDtInicialContrato, "-", ""), 8))    )
					lRet := oModel:SetValue( 'CN9MASTER', 'CN9_UNVIGE'  , '1'  )
					lRet := oModel:SetValue( 'CN9MASTER', 'CN9_VIGE'    , DateDiffDay( StoD(Left(StrTran(oWSContratoDTO:ctDtInicialContrato, "-", ""), 8)), StoD(Left(StrTran(oWSContratoDTO:ctDtFinalContrato, "-", ""), 8)) ) )
					lRet := oModel:SetValue( 'CN9MASTER', 'CN9_MOEDA'   , Val(aProposta[nZ]:csCdMoedaProposta)                  )
					lRet := oModel:SetValue( 'CN9MASTER', 'CN9_CONDPG'  , aProposta[nZ]:csCdCondicaoPagamento            )
					lRet := oModel:SetValue( 'CN9MASTER', 'CN9_FLGREJ'  , '2'  )
					lRet := oModel:SetValue( 'CN9MASTER', 'CN9_FLGCAU'  , '2'  )
					lRet := oModel:SetValue( 'CN9MASTER', 'CN9_DTPROP'  , StoD(Left(StrTran(aProposta[nZ]:ctDtProposta, "-", ""), 8))    )
					//lRet := oModel:SetValue( 'CN9MASTER', 'CN9_S_APRV'  , 'N'  ) // SENSUS 03/03/2021
					//lRet := oModel:SetValue( 'CN9MASTER', 'CN9_S_TP'    , 'C'  ) // SENSUS 03/03/2021
					lRet := oModel:SetValue( 'CN9MASTER', 'CN9_ASSINA'  , StoD(Left(StrTran(oWSContratoDTO:ctDtInicial, "-", ""), 8))    )
					lRet := oModel:SetValue( 'CN9MASTER', 'CN9_DESCRI'  , Posicione("SA2", 3, xFilial('SA2')+PADR(aProposta[nZ]:csCdEmpresa, Len(SA2->A2_CGC)), "A2_NOME")   )
					lRet := oModel:SetValue( 'CN9MASTER', 'CN9_NUMCOT'  , cNumCot  )
					lRet := oModel:LoadValue('CN9MASTER', 'CN9_LOGUSR'  , __cUserID ) //cCodUsua) Sensus 25/02/2021
					
					//Cliente/Fornecedor do Contrato
					lRet := oModel:SetValue( 'CNCDETAIL', 'CNC_FILIAL'  , SC1->C1_FILENT ) //SENSUS 03/03/2021
					lRet := oModel:SetValue( 'CNCDETAIL', 'CNC_CODIGO'  , SA2->A2_COD  )
					lRet := oModel:SetValue( 'CNCDETAIL', 'CNC_LOJA'    , SA2->A2_LOJA )
					lRet := oModel:SetValue( 'CNNDETAIL', 'CNN_USRCOD'  , __cUserID ) //cCodUsua) Sensus 25/02/2021
					lRet := oModel:SetValue( 'CNNDETAIL', 'CNN_TRACOD'  , '001'    )
					
					//Planilhas do Contrato
			  		lRet := oModel:SetValue( 'CNADETAIL', 'CNA_FILIAL'  , SC1->C1_FILENT ) //SENSUSS 03/03/2021
					lRet := oModel:LoadValue('CNADETAIL', 'CNA_CONTRA' , oModel:GetValue('CN9MASTER', 'CN9_NUMERO') )
					lRet := oModel:SetValue( 'CNADETAIL', 'CNA_NUMERO' , '000001'            )
					lRet := oModel:SetValue( 'CNADETAIL', 'CNA_FORNEC' , SA2->A2_COD  		 )
					lRet := oModel:SetValue( 'CNADETAIL', 'CNA_LJFORN' , SA2->A2_LOJA		 )
					lRet := oModel:SetValue( 'CNADETAIL', 'CNA_TIPPLA' , '001'             	 )
					lRet := oModel:SetValue( 'CNADETAIL', 'CNA_DTINI'  , StoD(Left(StrTran(aProposta[nZ]:ctDtProposta, "-", ""), 8))  )
					lRet := oModel:SetValue( 'CNADETAIL', 'CNA_DTFIM'  , StoD(Left(StrTran(aProposta[nZ]:ctDtValidade, "-", ""), 8))  )
					lCab := .T.
				EndIf
				If nX > 1
					xRetorno := oModel:GetModel('CNBDETAIL'):AddLine()
				Else
					oModel:GetModel('CNBDETAIL'):SetNoInsertLine(.F.) //Ativa insert
				EndIf
				//Itens da Planilha do Contrato
				lRet := oModel:SetValue( 'CNBDETAIL', 'CNB_ITEM'    , StrZero(nX, tamsx3("CNB_ITEM")[1]))
				lRet := oModel:SetValue( 'CNBDETAIL', 'CNB_PRODUT'  , aItens[nX]:csCdProduto       )
				lRet := oModel:SetValue( 'CNBDETAIL', 'CNB_QUANT'   , aPropEnd[1]:ndQtFornecimento )
				lRet := oModel:SetValue( 'CNBDETAIL', 'CNB_VLUNIT'  , aProposta[nZ]:ndVlUnitario   )
				lRet := oModel:SetValue( 'CNBDETAIL', 'CNB_PEDTIT'  , '1'                          )
				
				nVlTotal += Round(aPropEnd[1]:ndQtFornecimento * aProposta[nZ]:ndVlUnitario, 2)
				
				aNumSC := Separa(aEndereco[1]:csCdRequisicaoEmpresa, ".", .T.)
				cNumSC := IIf(Len(aNumSC) == 2 .And. !Empty(aNumSC[2]), aNumSC[2], aNumSC[1])
				
				dbSelectArea("SC1")
				dbSetOrder(1)
				If dbSeek(xFilial('SC1')+PADR(cNumSC,Len(SC1->C1_NUM))+PADR(aEndereco[1]:csCdItemRequisicaoEmpresa,Len(SC1->C1_ITEM)))
					lRet := oModel:SetValue( 'CNBDETAIL', "CNB_FILIAL" , SC1->C1_FILENT) // SENSUS 03/03/2021
					lRet := oModel:SetValue( 'CNBDETAIL', "CNB_NUMSC" , SC1->C1_NUM)
					lRet := oModel:SetValue( 'CNBDETAIL', "CNB_ITEMSC", SC1->C1_ITEM)
					//oModel:SetValue( 'CNBDETAIL', "CNB_DESCRI", SC1->C1_DESCRI)
					//oModel:SetValue( 'CNBDETAIL', "CNB_UM"    , SC1->C1_UM)
					lRet := oModel:SetValue( 'CNBDETAIL', 'CNB_QTDSOL', aPropEnd[1]:ndQtFornecimento  )
					lRet := oModel:SetValue( 'CNBDETAIL', "CNB_CONTA" , SC1->C1_CONTA)
					lRet := oModel:SetValue( 'CNBDETAIL', "CNB_ITEMCT", SC1->C1_ITEMCTA)
			  		lRet := oModel:SetValue( 'CNBDETAIL', "CNB_CC"    , SC1->C1_CC)
			  		lRet := oModel:SetValue( 'CNBDETAIL', "CNB_CLVL"  , SC1->C1_CLVL)
			  		lRet := oModel:SetValue( 'CNBDETAIL', "CNB_EC05DB", SC1->C1_EC05DB)
				EndIf
				
				lRet := oModel:SetValue( 'CNBDETAIL', 'CNB_XPEDWB'  , cPedWS				       )
				lRet := oModel:SetValue( 'CNBDETAIL', 'CNB_XITWBC'  , aItens[nX]:csCdItemWbc	   )
				lRet := oModel:SetValue( 'CNBDETAIL', 'CNB_XTPORI'  , 2					           )
				lRet := oModel:SetValue( 'CNBDETAIL', 'CNB_XPROPO'  , aProposta[nZ]:nnCdProposta   )
				lRet := oModel:SetValue( 'CNBDETAIL', 'CNB_XCOTAC'  , oWSContratoDTO:csCdCotacaoERP)
				                              
				//Cronograma Financeiro
				/*lRet := oModel:GetModel('CNFDETAIL'):SetNoInserLine(.F.)
				lRet := oModel:GetModel('CNFDETAIL'):SetNoUpdateLine(.F.)
				 
				lRet := oModel:LoadValue( 'CNFDETAIL', 'CNF_NUMERO'  , '000001'             )
				lRet := oModel:SetValue( 'CNFDETAIL' , 'CNF_PARCEL'  , '01'                 )
				lRet := oModel:SetValue( 'CNFDETAIL' , 'CNF_COMPET'  , Month2Str(Date()) + '/' + Year(Date()) )
				lRet := oModel:SetValue( 'CNFDETAIL' , "CNF_VLPREV"  , nVlTotal             )
				lRet := oModel:SetValue( 'CNFDETAIL' , "CNF_VLREAL"  , 0                    )
				lRet := oModel:SetValue( 'CNFDETAIL' , "CNF_SALDO"   , nVlTotal             )
				lRet := oModel:SetValue( 'CNFDETAIL' , 'CNF_PRUMED'  , Date()    			)
				lRet := oModel:SetValue( 'CNFDETAIL' , 'CNF_DTVENC'  , Date()    			)
				lRet := oModel:SetValue( 'CNFDETAIL' , 'CNF_TXMOED'  , 1                    )
				
				//Cronograma Financeiro
				aAdd(aPergunte,1)//Periodicidade: 1=Mensal, 2=Quinzenal, 3=Diario, 4=Cond. Pag.
				aAdd(aPergunte,30)//Dia(s)?
				aAdd(aPergunte,.T.)//Ultimo dia do mes? .T.=SIM, .F.=NAO
				aAdd(aPergunte,"12/2018")//Competencia de inicio?
				aAdd(aPergunte,CToD("20/12/2018"))//Data prevista 1? medicao
				aAdd(aPergunte,12)//Quantidade de parcelas
				aAdd(aPergunte,"   ")//Condicao de Pagamento?
				aAdd(aPergunte,.F.)//Se for mensal(Periodicidade: 1=Mensal) e Ultimo dia do Mes=SIM, entao deve ser .T., caso contrario .F.
				//Gera cronograma de forma automatica
				CN300AddCrg(aPergunte)			*/
				For nW := 1 To Len(aTaxa)
					cItem    := StrZero(nZ,tamsx3("C3_ITEM")[1])
					
					dbSelectArea("ZIP")
					dbSetOrder(1)
					//If !dbSeek(xFilial('ZIP')+cNum+cItem)
						RecLock("ZIP", .T.)
					/*Else
						RecLock("ZIP", .F.)
					EndIf*/
					ZIP->ZIP_FILIAL := xFilial('ZIP') 
					ZIP->ZIP_NUM    := cNum
					ZIP->ZIP_ITEM   := cItem
					ZIP->ZIP_INCLUS := aTaxa[nW]:nbFlIncluso
					ZIP->ZIP_TAXA   := aTaxa[nW]:ndPcTaxa
					ZIP->ZIP_CODTAX := aTaxa[nW]:nnCdTaxa
					ZIP->ZIP_PEDPAR := cPedWS
					ZIP->ZIP_ITEPAR := aItens[nX]:csCdItemWbc
					MsUnLock()
					
				Next nW
			Next nZ
		Next nX
		
		nProc++
		If !Empty(NomeAutoLog())
			MemoWrite( NomeAutoLog(), ' ' )
		EndIf
		
		//Validacao e Gravacao do Modelo
		If oModel:VldData()
		    oModel:CommitData()
		    
			conout(" Contrato " + cNum + " integrado com sucesso!")
			oLog:Retorno   := 1
			oLog:Origem    := cOrigem
			oLog:MsgLog    := "Contrato " + cNum + " integrado com sucesso!"
			oLog:SoapFault := "Contrato " + cNum + " integrado com sucesso!"
			oLog:Tstamp    := FwTimeStamp(3)
			oLog:Token     := 'CNTA300'		
			oLog:SalvaObj('CN9')
			
			nPrcContra(oWSContratoDTO, aPedido[nY][2], cNum, nVlTotal)
			nProc++
			
			dbSelectArea("CNB")
			dbSetOrder(1)
			dbSeek(xFilial("CNB")+cNum+CN9->CN9_REVISA)
			While CNB->(!EoF()) .And. CNB->CNB_FILIAL == xFilial('CNB') .And. CNB->CNB_CONTRA == cNum .And. CNB->CNB_REVISA == CN9->CN9_REVISA
				cAliCo:= GetNextAlias()
				cQuery := " select R_E_C_N_O_ REG from  " + RetSqlTab("SC8")
			 	cQuery += " where D_E_L_E_T_ = ' ' "
			 	cQuery += "   and C8_XCODPAR = '" + CNB->CNB_XPEDWB + "' "
			 	cQuery += "   and C8_XITEPAR = '" + CNB->CNB_XITWBC  + "' "
			 	cQuery += "   and C8_XNPROPA =  " + cValToChar(CNB->CNB_XPROPO)
			 	cQuery += "   and C8_XCOTACA = '" + CNB->CNB_XCOTAC + "' "
			 	OPENSQL(cAliCo, cQuery)
				dbSelectArea(cAliCo)
			 	If (cAliCo)->( ! EoF() )
					DbSelectArea('SC8')
					SC8->( DbGoTo( (cAliCo)->REG ) )
					RecLock('SC8', .F.)
					SC8->C8_VLDESC	:= CNB->CNB_VLDESC	//Vl. Desconto		
					SC8->C8_DESC	:= CNB->CNB_DESC	//% Desc. Item	SIM	realizar calculo
					SC8->C8_NUMCON	:= CNB->CNB_CONTRA	//Num.Contrato
					MsUnlock()
					
					dbSelectArea("SC1")
					dbSetOrder(1)
					If dbSeek(xFilial('SC1')+CNB->CNB_NUMSC+CNB->CNB_ITEMSC)
						RecLock('SC1', .F.)
						SC1->C1_COTACAO := SC8->C8_NUM
						MsUnlock()
					EndIf
				EndIf
				CLOSESQL(cAliCo)
				CNB->(DbSkip())
			EndDo
	
			//Sensus - 25/02/2021 - Forca gravacao no usuario na CN9
			DbSelectArea("CN9")
			DbSetorder(1) //CN9_FILIAL+CN9_NUMERO+CN9_REVISA
			If DbSeek(xFilial("CN9")+cNum)
				
			   RecLock("CN9",.F.)
			   CN9->CN9_LOGUSR := __cUserID
			   MsUnlock()
			
			Endif
		     
		    Conout("Usuario da CN9-> "+CN9->CN9_LOGUSR)
		    
			//Sensus - 09/03/2021 - Forca gravacao no usuario na CNN
			DbSelectArea("CNN")
			DbSetorder(1) //CNN_FILIAL+CNN_USRCOD+CNN_CONTRA+CNN_TRACOD
			If DbSeek(xFilial("CNN")+"      "+cNum)
				
			   RecLock("CNN",.F.)
			   CNN->CNN_USRCOD := __cUserID
			   MsUnlock()
			
			Endif
		    
		    Conout("Usuario da CNN-> "+CNN->CNN_USRCOD)
		   
		Else
			aErro := oModel:GetErrorMessage()
		    //TmsMsgErr(aErro)
		    For nE := 1 To Len(aErro)
		    	cErro += AllToChar(aErro[nE]) + CRLF
		    Next nE
		    AutoGrLog( "Id do formulario de origem:" + ' ' + AllToChar( aErro[1]  ) )
			AutoGrLog( "Id do campo de origem:     " + ' ' + AllToChar( aErro[2]  ) )
			AutoGrLog( "Id do formulario de erro:  " + ' ' + AllToChar( aErro[3]  ) )
			AutoGrLog( "Id do campo de erro:       " + ' ' + AllToChar( aErro[4]  ) )
			AutoGrLog( "Id do erro:                " + ' ' + AllToChar( aErro[5]  ) )
			AutoGrLog( "Mensagem do erro:          " + ' ' + AllToChar( aErro[6]  ) )
			AutoGrLog( "Mensagem da solucao:       " + ' ' + AllToChar( aErro[7]  ) )
			AutoGrLog( "Valor atribuido:           " + ' ' + AllToChar( aErro[8]  ) )
			AutoGrLog( "Valor anterior:            " + ' ' + AllToChar( aErro[9]  ) )
			cErro := MostraErro()
		    //alert('erro: ' + cErro)
		    
			lerro := .T.
			conout(PADR("ERROR - " +PADR(ProcName(1),10) + " - Tempo " +FWTimeStamp(2) +" - ",60) + 'Erro CNTA300: ' + IIf(!Empty(NomeAutoLog()),MemoRead(NomeAutoLog()), cErro))
			oLog:Retorno   := 0
			oLog:Origem    := cOrigem
			oLog:MsgLog    := 'Erro CNTA300 - ' + IIf(!Empty(NomeAutoLog()),MemoRead(NomeAutoLog()), cErro)
			oLog:SoapFault := 'Erro CNTA300 - ' + IIf(!Empty(NomeAutoLog()),MemoRead(NomeAutoLog()), cErro)
			oLog:Tstamp    := FwTimeStamp(3)
			oLog:Token     := 'CNTA300'		
			oLog:SalvaObj('CN9')
			oLog:novoLog()
			
			If !Empty(NomeAutoLog())
				MemoWrite( NomeAutoLog(), ' ' )
			EndIf
			
			fHabiPed(2, cPedWS, aPedWS, oLog)
			
		EndIf
		oModel:DeActivate()
		oLog:novoLog()
	Next nY
	
	__cUserID := cUserAux
	cFilAnt := cFilAux
	End Sequence
	ErrorBlock(oError)
Return

/////////////////////////////////////////////////////////
// *************************************************** //
/////////////////////////////////////////////////////////
Static Function nPrcContra(oWSContratoDTO, aItens, cNumCT, nTotal)
	Local cTab     := "CNB"
	Local aReg     := {}
	Local oLog     := Nil
	Local nProc    := 0
	Local nX	   := 0
	Local cEmpresa := ''
	Local cAlias   := GetNextAlias()
	Local oError   := ErrorBlock({|e| fErrorPar(e:ErrorStack, cTab, @oLog, @cNumCT)})
	Local oWsCtrIt := Nil
	Local oWsContr := Nil
	Local oCt	   := Nil
	Local oIt  	   := Nil
	Local oEnd	   := Nil
	
	Default aItens := {}
	Begin Sequence
	fIniLog("Contrato")

	oLog :=  FwParLog():New("PAR001", "ProcessarContrato")
		
	oWsContr:= WSContrato():New()
	oCt := Contrato_ContratoDTO():New()
	oCt:oWSlstContratoItemDTO := Contrato_ArrayOfContratoItemDTO():New()
	For nX := 1 To Len(aItens)
		aProposta := aItens[nX]:oWSlstCotacaoPropostaDTO:oWSParCotacaoPropostaDTO[1]
		aPropEnd  := aProposta:oWSlstCotacaoPropostaEnderecoDTO:oWSParCotacaoPropostaEnderecoDTO[1]
		cEmpresa  := aProposta:csCdEmpresa
	
		oIt := Contrato_ContratoItemDTO():New()
		
		oIt:ndQtItemPrevisto		:= aItens[nX]:ndQtItem
		oIt:ndQtItemRealizado		:= aItens[nX]:ndQtItem 
		//oIt:dQtLoteMinimo>?<!--Optional:-->
		//oIt:dQtLoteMultiplo>?<!--Optional:-->
		oIt:ndVlItem				:= aProposta:ndVlProposta
		oIt:oWSlstContratoItemEnderecoDTO := Contrato_ArrayOfContratoItemEnderecoDTO():New()
		oEnd := Contrato_ContratoItemEnderecoDTO():New()			
		oEnd:ndQtItemPrevista					:= aItens[nX]:ndQtItem
		oEnd:ndQtItemRealizado 					:= aPropEnd:ndQtFornecimento
		oEnd:csCdCobrancaEndereco				:= '' //<!--Optional:-->
		oEnd:csCdEmpresaCobrancaEndereco		:= oWSContratoDTO:csCdEmpresa //<!--Optional:-->
		oEnd:csCdEmpresaEntregaEndereco			:= oWSContratoDTO:csCdEmpresa //<!--Optional:-->
		oEnd:csCdEmpresaFaturamentoEndereco		:= oWSContratoDTO:csCdEmpresa //<!--Optional:-->
		oEnd:csCdEntregaEndereco				:= '' //<!--Optional:-->
		oEnd:csCdFaturamentoEndereco			:= '' //<!--Optional:-->
		oEnd:csCdItemEnderecoWbc				:= aItens[nX]:csCdItemWbc
		oEnd:ctDtEntregaPrevista				:= aPropEnd:ctDtFornecimento
		oEnd:ctDtEntregaRealizado				:= aPropEnd:ctDtFornecimento
		oEnd:ndVlAliquota						:= 0
		oEnd:oWSlstContratoItemEnderecoTaxaDTO 	:= Contrato_ArrayOfContratoItemTaxaDTO():New()
		oTx := Contrato_ContratoItemTaxaDTO():New()
		oTx:nbFlIncluso := 0
		oTx:ndPcTaxa    := 0
		oTx:nnCdTaxa    := 2
		AADD(oEnd:oWSlstContratoItemEnderecoTaxaDTO:oWSContratoItemTaxaDTO, oTx:Clone())
		//<par:nIdSuperSimples>?<!--Optional:-->
		AADD(oIt:oWSlstContratoItemEnderecoDTO:oWSContratoItemEnderecoDTO, oEnd:Clone())
		
		oIt:nnCdSituacaoItem		:= 1 //aItens[nX]:nnCdSituacao
		oIt:csCdClasse				:= aItens[nX]:csCdClasse
		oIt:csCdCondicaoPagamento	:= aItens[nX]:csCdCondicaoPagamento
		oIt:csCdFrete				:= aProposta:csCdFrete
		//oIt:sCdGarantia>?	<!--Optional:-->
		//oIt:sCdItemErp>?	<!--Optional:-->
		//oIt:sCdItemPaiErp>?	<!--Optional:-->
		oIt:csCdItemWbc				:= aItens[nX]:csCdItemWbc  //<!--Optional:-->
		//oIt:sCdIva>?	<!--Optional:-->
		//oIt:sCdMarca>?	<!--Optional:-->
		oIt:csCdNegociacaoItemWbc	:= aItens[nX]:csCdItemWbc
		oIt:csCdProduto				:= aItens[nX]:csCdProduto
		//oIt:sCdProjeto>?<!--Optional:-->
		oIt:csCdUnidadeMedida		:= aItens[nX]:csCdUnidadeMedida
		//oIt:sDsObservacoes>?<!--Optional:-->
		oIt:csDsProdutoContrato		:= aItens[nX]:csDsItem
		
		AADD(oCt:oWSlstContratoItemDTO:oWSContratoItemDTO, oIt:Clone())
	Next nX
	
	oCt:nbFlPrazoIndeterminado	:= 0
	//oCt:bFlRenovacaoAuto>?<!--Optional:-->
	oCt:ndVlContrato			:= nTotal
	oCt:nnCdSituacao 			:= 3
	oCt:nnCdTipo				:= oWSContratoDTO:nnIdTipoNegociacao
	//oCt:nIdTipo>?<!--Optional:-->
	oCt:nnIdTipoOrigem			:= 2
	oCt:nnNrDiasAvisoFim		:= 30
	oCt:nnNrDiasAvisoPedido		:= 30
	oCt:nnNrDiasAvisoRescisao	:= 30
	oCt:nnNrDuracao				:= 30
	//<!--Optional:-->
	oCt:csCdContrato			:= cNumCT			
	oCt:csCdContratoErp			:= cNumCT
	//oCt:sCdContratoErpPai>?<!--Optional:-->
	oCt:csCdContratoWbc			:= cNumCT //oWSContratoDTO:csCdCotacaoWbc
	//oCt:sCdDepartamento>?<!--Optional:-->
	oCt:csCdEmpresaContratada	:= cEmpresa
	oCt:csCdEmpresaContratante	:= oWSContratoDTO:csCdEmpresa
	oCt:csCdMoeda				:= oWSContratoDTO:csCdMoeda
	oCt:csCdNegociacaoWbc 		:= oWSContratoDTO:csCdCotacaoWbc
	//oCt:sCdProjeto>?<!--Optional:-->
	//oCt:sCdTransportadora>?<!--Optional:-->
	oCt:csCdUsuario				:= oWSContratoDTO:csCdUsuario
	oCt:csCdUsuarioCriador      := oWSContratoDTO:csCdUsuario
	oCt:csCdUsuarioGestor       := oWSContratoDTO:csCdUsuario
	//oCt:sDsAuditoria>?<!--Optional:-->
	oCt:csDsContrato			:= oWSContratoDTO:csDsCotacao
	oCt:csDsObjeto				:= oWSContratoDTO:csDsCotacao
	oCt:ctDtAssinatuta			:= oWSContratoDTO:ctDtCadastro
	oCt:ctDtCadastro			:= oWSContratoDTO:ctDtCadastro
	oCt:ctDtFinal				:= oWSContratoDTO:ctDtFinal
	oCt:ctDtInicial				:= oWSContratoDTO:ctDtInicial
	//oCt:tDtReajuste>?</par:tDtReajuste><!--Optional:-->
	oCt:ctDtRescisao			:= oWSContratoDTO:ctDtFinal
	
	AADD(oWsContr:oWSlstContrato:oWSContratoDTO, oCt:Clone())
	
	If oWsContr:ProcessarContrato()
		fWsLogRet( oWsContr:oWSProcessarContratoResult:oWSlstWbtLogDTO:oWSWbtLogDTO, oLog, cTab, aReg, @nProc)	
	Else
		fSoapFault(oLog)
	EndIf
	
 	fFimLog("Contrato - " + cValToChar(nProc) + ' processados - ' + Time())

	End Sequence
	ErrorBlock(oError)

Return nProc


/*/{Protheus.doc} lGeraPC
//Gera o pedido de compras conforme pedido do portal
@author fr
@since 23/05/2018
@version 2.0
@param oWSParPedidoDTO, object, objeto de retorno do pedido do portal
@param cNumSC, characters, N?mero da solicita??o de compras
@type function
/*/
Static Function lGeraPC(oWSParPedidoDTO, oLog, nProc)
	Local aMt120Cb := {}
	Local aMt120It := {}
	Local aMata120 := {}
	Local aEntrega := {}
	Local aTaxa    := {}
	Local aItens   := {}
	Local aPedWS   := {}
	Local lProblem := .F.
	Local nOpcAuto := 3
	Local nX       := 0
	Local nY       := 0
	Local nZ       := 0
	Local nW       := 0
	Local cNum     := ''
	Local cUpd     := ''
	Local cItem    := ''
	Local cPedWS   := ''
	Local cQuery   := ''
	Local cAlias   := ''
	Local cOrigem  := ''
	Local cFilPed  := ''
	Local cReqEmp  := ''
	Local cCodUser := ''
	Local cCodComp := ''
	Local cUsuario := ''
	Local cUserAux := __cUserID
	Local cDifere  := ''
	Local cFilAux  := cFilAnt
	Local oError   := ErrorBlock({|e| fErrorPar(e:ErrorStack, 'SC7', @oLog, @cPedWS, @nY, @oWSParPedidoDTO, @cOrigem, @cDifere, @nX)})
	Local aEmpFil  := FWLoadSM0()

	Private lMsErroAuto := .F.
	
	Begin Sequence
	conout(' ' + cValToChar(Len(oWSParPedidoDTO)) + ' ' + oLog:Funcao)
	For nY := 1 To Len(oWSParPedidoDTO)
		oLog:Usuario := oWSParPedidoDTO[nY]:csCdUsuario
		cPedWS       := oWSParPedidoDTO[nY]:csCdPedidoWBC
		aItens       := oWSParPedidoDTO[nY]:oWSlstPedidoItem:oWSParPedidoItemDTO
		nPos         := aScan(aEmpFil, {|x| x[18] == aItens[1]:csCdEmpresa})
		cFilAnt      := aEmpFil[nPos][2]
		cOrigem      := oWSParPedidoDTO[nY]:csCdPedidoERP + '  ' + cPedWS
		aPedWS       := {}
		aMt120Cb     := {}
		aMt120It     := {}
		lMsErroAuto  := .F.
		lProblem     := .F.
		cDifere      := aItens[1]:oWslstPedidoItemEntrega:oWSParPedidoItemEntregaDTO[1]:csCdRequisicaoEmpresa
		cDifere      += aItens[1]:oWslstPedidoItemEntrega:oWSParPedidoItemEntregaDTO[1]:csCdItemRequisicaoEmpresa
		cDifere      += aItens[1]:oWslstPedidoItemEntrega:oWSParPedidoItemEntregaDTO[1]:csCdCentroCustoRequisicao
		
		oLog:Funcao := "RetornarPedidoLeilao"
		
		cAlias := GetNextAlias()
		cQuery := " select max(C7_NUM) NUM from  " + RetSqlTab("SC7")
	 	cQuery += " where C7_FILIAL = '" + cFilAnt + "' "
	
		OPENSQL(cAlias, cQuery)
	
	 	If (cAlias)->( ! EoF() )
	 		cNum := Soma1((cAlias)->NUM)
	 		dbSelectArea("SC7")
	 		dbSetOrder(1)
	 		While dbSeek(xFilial("SC7")+cNum )
	 			cNum := Soma1(cNum)
			EndDo
	 	EndIf
	 	CLOSESQL(cAlias)
		
		/*CriaVar('C7_NUM', .T.)*/
		conout(' _Criando pedido: ' + cFilAnt + '_' + cNum)
		
		dbSelectArea("SA2")
		dbSetOrder(3)  //A2_FILIAL+A2_CGC
		dbSeek(xFilial('SA2')+PADR(oWSParPedidoDTO[nY]:csCdFornecedor, Len(SA2->A2_CGC)))
		
		AADD(aMt120Cb, {"C7_FILIAL" , cFilAnt									      , Nil})
		//AADD(aMt120Cb, {"C7_FILENT" , cFilPed									      , Nil})
		AADD(aMt120Cb, {"C7_NUM"    , cNum											  , Nil})
		AADD(aMt120Cb, {"C7_FORNECE", SA2->A2_COD									  , Nil})
		AADD(aMt120Cb, {"C7_LOJA"   , SA2->A2_LOJA									  , Nil})
		AADD(aMt120Cb, {"C7_EMISSAO", Date()										  , Nil})
		AADD(aMt120Cb, {"C7_COND"   , oWSParPedidoDTO[nY]:csCdCondicaoPagamento		  , Nil})
		AADD(aMt120Cb, {"C7_TPFRETE", oWSParPedidoDTO[nY]:csCdFrete                   , Nil})
		AADD(aMt120Cb, {"C7_MOEDA"  , Val(oWSParPedidoDTO[nY]:csCdMoeda)              , Nil})
		aAdd(aMt120Cb, {"C7_TXMOEDA", RecMoeda(Date(), Val(oWSParPedidoDTO[nY]:csCdMoeda)), Nil })
		
		cItem := StrZero(0,tamsx3("C7_ITEM")[1])
		For nX := 1 To Len(aItens)	
			aMata120 := {}
			aEntrega := aItens[nX]:oWslstPedidoItemEntrega:oWSParPedidoItemEntregaDTO
			aTaxa    := aItens[nX]:oWslstPedidoItemTaxa:oWSParPedidoItemTaxaDTO
			cUsuario := PADR(Iif(!Empty(aItens[nX]:csCdUsuarioResponsavel), aItens[nX]:csCdUsuarioResponsavel, oWSParPedidoDTO[nY]:csCdUsuario), tamsx3("ZUP_NOMRED")[1])
			cCodUser := POSICIONE('ZUP', 2, cUsuario, 'ZUP_CODUSU')
			If !Empty(cCodUser)
				__cUserID := cCodUser
			EndIf
			Iif(nX == 1, (cOrigem += '-' + aItens[nX]:csCdItemWbc), (cOrigem += ',' + aItens[nX]:csCdItemWbc))
			
			For nW := 1 To Len(aEntrega)
				aMata120 := {}
				cItem    := Soma1(cItem)
				aNumSC := Separa(aEndereco[nW]:csCdRequisicaoEmpresa, ".", .T.)
				cNumSC := IIf(Len(aNumSC) == 2 .And. !Empty(aNumSC[2]), aNumSC[2], aNumSC[1])
				//cReqEmp  := aEntrega[nW]:csCdRequisicaoEmpresa
				aADD(aPedWS, aItens[nX]:csCdItemWbc)
				
				cAlias := GetNextAlias()
				cQuery := " select C7_NUM NUM from  " + RetSqlTab("SC7")
			 	cQuery += " where D_E_L_E_T_ = '' "
			 	cQuery += "   and C7_NUMSC   = '" + cNumSC + "' "
			 	cQuery += "   and C7_ITEMSC  = '" + aEntrega[nW]:csCdItemRequisicaoEmpresa + "' "
			 	cQuery += "   and C7_XPEDWBC = '" + cPedWS + "' "
			 	cQuery += "   and C7_XITWBC  = '" + aItens[nX]:csCdItemWbc + "' "
			
				OPENSQL(cAlias, cQuery)
			
			 	If (cAlias)->( ! EoF() )
			 		cErro := 'Ja existe o pedido ' + (cAlias)->NUM + ' com a solicitacao ' + aEntrega[nW]:csCdRequisicaoEmpresa + ' ' + aEntrega[nW]:csCdItemRequisicaoEmpresa
			 		Conout(cErro)
			 		oLog:Retorno   := 0
					oLog:Origem    := cOrigem
					oLog:MsgLog    := 'Erro: ' + cErro
					oLog:SoapFault := 'Erro: ' + cErro
					oLog:Tstamp    := FwTimeStamp(3)
					oLog:Token     := 'Gera Pedido'
					oLog:DIfere    := cDIfere
					oLog:SalvaObj('SC7')
					oLog:novoLog()
			 		
			 		lProblem := .T.
			 		CLOSESQL(cAlias)
			 		Exit		 		
			 	EndIf
			 	CLOSESQL(cAlias)
				
				AADD(aMata120, {"C7_ITEM"   , cItem                              , Nil})
				AADD(aMata120, {"C7_PRODUTO", aItens[nX]:csCdProduto             , Nil})
				AADD(aMata120, {"C7_DESC"   , aItens[nX]:ndPcDesconto            , Nil})
				AADD(aMata120, {"C7_PRECO"  , aItens[nX]:ndVlItem                , Nil})
				
				AADD(aMata120, {"C7_XINTPA" , '2'                                , Nil})
				AADD(aMata120, {"C7_XTPORIG", 1		                             , Nil}) // 1-leilao 2-cotacao 3-contrato
				AADD(aMata120, {"C7_XITWBC" , aItens[nX]:csCdItemWbc             , Nil})
				AADD(aMata120, {"C7_XPEDWBC", cPedWS                             , Nil})
				If !Empty(oWSParPedidoDTO[nY]:csCdPedidoERP)
					//'C7_XPROPOS'
					AADD(aMata120, {"C7_XCOTACA", oWSParPedidoDTO[nY]:csCdPedidoERP, Nil})
				EndIf
				
				AADD(aMata120, {"C7_QUANT"  , aEntrega[nW]:ndQtEntrega								   , Nil})
				AADD(aMata120, {"C7_DATPRF" , StoD(Left(StrTran(aEntrega[nW]:ctDtEntrega, "-", ""), 8)), Nil})
				
				dbSelectArea("SC1")
				dbSetOrder(2)
				If dbSeek(xFilial('SC1')+PADR(aItens[nX]:csCdProduto,Len(SC7->C7_PRODUTO))+PADR(cNumSC,Len(SC7->C7_NUMSC))+PADR(aEntrega[nW]:csCdItemRequisicaoEmpresa,Len(SC7->C7_ITEMSC)))
					aAdd(aMata120, {"C7_OBS"    , SC1->C1_OBS  	      				  	, Nil})
					aAdd(aMata120, {"C7_LOCAL"  , SC1->C1_LOCAL						  	, Nil})
					AADD(aMata120, {"C7_NUMSC"  , cNumSC							    , Nil})
					AADD(aMata120, {"C7_ITEMSC" , aEntrega[nW]:csCdItemRequisicaoEmpresa, Nil})
					aAdd(aMata120, {"C7_CC"     , SC1->C1_CC	                        , Nil})
					AADD(aMata120, {"C7_CONTA"  , SC1->C1_CONTA                         , Nil})
					//If !Empty(SC1->C1_ITEMCTA)
						AADD(aMata120, {"C7_ITEMCTA", SC1->C1_ITEMCTA                   , Nil})
					//EndIf
					aAdd(aMata120, {"C7_CLVL"   , SC1->C1_CLVL                          , Nil})
					aAdd(aMata120, {"C7_EC05DB" , SC1->C1_EC05DB                        , Nil})
				EndIf
				
				For nZ := 1 To Len(aTaxa)
					If aTaxa[nZ]:nnCdTaxa == 1
	                	AADD(aMata120, {"C7_PICM"    , aTaxa[nZ]:ndPcTaxa, Nil})
	                EndIf
	                If aTaxa[nZ]:nnCdTaxa == 2
	                	AADD(aMata120, {"C7_IPI"     , aTaxa[nZ]:ndPcTaxa, Nil})
	                EndIf
	                If aTaxa[nZ]:nnCdTaxa == 4
	                	AADD(aMata120, {"C7_ALIQISS" , aTaxa[nZ]:ndPcTaxa, Nil})
	                EndIf
	                If aTaxa[nZ]:nnCdTaxa == 5 //.And. aTaxa[nZ]:ndPcTaxa > 0
	                	AADD(aMata120, {"C7_ICMSRET" , Round( Round(aItens[nX]:ndVlItem * aEntrega[nW]:ndQtEntrega, 2) * (aTaxa[nZ]:ndPcTaxa / 100), 2), Nil})
	                EndIf
	                
	                dbSelectArea("ZIP")
					dbSetOrder(1)
					If !dbSeek(xFilial('ZIP')+cNum+cItem)
						RecLock("ZIP", .T.)
					Else
						RecLock("ZIP", .F.)
					EndIf					
					ZIP->ZIP_FILIAL := xFilial('ZIP') 
					ZIP->ZIP_NUM    := cNum
					ZIP->ZIP_ITEM   := cItem
					ZIP->ZIP_INCLUS := aTaxa[nZ]:nbFlIncluso
					ZIP->ZIP_TAXA   := aTaxa[nZ]:ndPcTaxa
					ZIP->ZIP_CODTAX := aTaxa[nZ]:nnCdTaxa
					ZIP->ZIP_PEDPAR := cPedWS
					ZIP->ZIP_ITEPAR := aItens[nX]:csCdItemWbc
					MsUnLock()
					
				Next nZ
		
				AADD(aMt120It, aClone(aMata120))
			Next nW
		Next nX
		
		If lProblem
			Loop
		EndIf
		
		AADD(aMt120Cb, {"C7_USER" , __cUserID	, Nil})
		
		nProc++
		If !Empty(NomeAutoLog())
			MemoWrite( NomeAutoLog(), ' ' )
		EndIf
		
		//aEval(aMt120It, {|arr| aEval(arr, {|arr2| arr2[3] := ".T." }) })
		
		MSExecAuto({|x,y,z| MATA120(1, x, y, z) }, aMt120Cb, aMt120It, nOpcAuto)
		
		If !lMsErroAuto
			cNum := SC7->C7_NUM
			conout(" Pedido de compra " + cNum + " integrado com sucesso!")
			oLog:Retorno   := 1
			oLog:Origem    := cOrigem
			oLog:MsgLog    := "Pedido de compra " + cNum + " integrado com sucesso!"
			oLog:SoapFault := "Pedido de compra " + cNum + " integrado com sucesso!"
			oLog:Tstamp    := FwTimeStamp(3)
			oLog:Token     := 'MATA120'		
			oLog:Difere    := cDifere
			oLog:SalvaObj('SC7')
			
			/*cCodComp := POSICIONE('SY1', 3, xFilial('SY1') + cCodUser , 'Y1_COD')
			 
			cUpd := " UPDATE " + RetSqlName('SC7')
			cUpd += " SET C7_USER      = " + ValToSql(cCodUser)
			cUpd += " ,   C7_XCODCOM   = " + ValToSql(cCodComp)
			cUpd += " WHERE D_E_L_E_T_ = '' " 
			cUpd += "   AND C7_FILIAL  = " + ValToSql(xFilial('SC7')) 
			cUpd += "   AND C7_NUM     = " + ValToSql(cNum)
	
			if TcSqlExec(cUpd) < 0
				conout("ERRO AO ATUALIZAR OS REGISTROS DA TABELA " + 'SC7')
				conout(TcSqlError())
			endIf*/
		Else
			conout(PADR("ERROR - " +PADR(ProcName(1),10) + " - Tempo " +FWTimeStamp(2) +" - ",60) + 'Erro MATA120 ' + Iif(!Empty(NomeAutoLog()),MemoRead(NomeAutoLog()),''))
			oLog:Retorno   := 0
			oLog:Origem    := cOrigem
			oLog:MsgLog    := 'Erro MATA120 ' + Iif(!Empty(NomeAutoLog()),MemoRead(NomeAutoLog()),'')
			oLog:SoapFault := 'Erro MATA120 ' + Iif(!Empty(NomeAutoLog()),MemoRead(NomeAutoLog()),'')
			oLog:Tstamp    := FwTimeStamp(3)
			oLog:Token     := 'MATA120'
			oLog:Difere    := cDifere
			oLog:SalvaObj('SC7')
			oLog:novoLog()
			
			MemoWrite( NomeAutoLog(), ' ' )
			
			fHabiPed(1 /*Leilao*/, cPedWS, aPedWS, oLog)
			
		EndIf
		oLog:novoLog()
	Next nY	
	
	__cUserID := cUserAux
	cFilAnt   := cFilAux
	End Sequence
	ErrorBlock(oError)
Return


/*/{Protheus.doc} lLockRot
//Efetua o lock de acesso a rotina
@author fabricio.reche
@since 07/08/2019
@version 1.0
@type function
/*/
Static Function lLockRot()
    Local cLock := ""

    Local cElapsed := ""
	local cHoraPar := ""
	Local cMv_XParLock := GetMv("MV_XPARLOK")
    Local aArray := {}

	If !Empty(cLock := GetMv("MV_XPARLOK"))
	
		aArray 	 := StrToKarr( cMv_XParLock , '|') 	//Quebra Valor do parÃ¢metro pelo PIPE
		cHoraPar := SubStr(AllTrim(aArray[2]),23,8) //Pega o valor da HORA:MINUTO:SEGUNDO
		cElapsed := ElapTime( cHoraPar, TIME() ) 	//Calcula a diferenca do horario atual com o ultimo processamento.
		IF cElapsed > "00:10:01" // Limpa valor do parÃ‚metro.
			lUnLockRot()
		Else
			Aviso("Esta rotina esta em uso por outro usuario!", cLock, {"Ok"}, 3)
			conout("Esta rotina esta em uso por outro usuario! " + cLock)
			Return .F.
		EndIf
	EndIf

	cLock := "Usuario: "        + cUserName
	cLock += " | Data e hora: " + dToC(Date()) + " " + Time()
	cLock += " | Computador: "  + GetComputerName()
	cLock += " | Ambiente: "    + GetEnvServer()
	cLock += " | ThreadID: "    + cValToChar(ThreadId())

	PutMv("MV_XPARLOK", cLock)
Return .T.

/*/{Protheus.doc} lUnLockRot
//Efetua a libera??o do lock de acesso a rotina
@author fabricio.reche
@since 07/08/2019
@version 1.0
@type function
/*/
Static Function lUnLockRot()
    
    PutMv("MV_XPARLOK", " ")

Return .T.

/*/{Protheus.doc} AjustaPerg
//Ajusta os parametros da rotina
@author fabricio.reche
@since 07/08/2019
@version 1.0
@param cPerg, characters, Grupo de perguntas da SX1
@type function
/*/
Static Function AjustaPerg(cPerg)
	Local aPergs := {}
	Local cOrdSx := ""
	Local nX     := 0

	aAdd(aPergs, "Usuario")
	aAdd(aPergs, "Banco")
	aAdd(aPergs, "Cotacao Moeda")
	aAdd(aPergs, "Categoria")
	aAdd(aPergs, "Unidade de Medida")
	aAdd(aPergs, "Produto")
	aAdd(aPergs, "Condicao de Pagamento")
	aAdd(aPergs, "Centro de Custo")
	aAdd(aPergs, "Conta Contabil")
	aAdd(aPergs, "Grupo Compra")
	aAdd(aPergs, "Fornecedor")
	aAdd(aPergs, "Solicitacao de Compra")
	aAdd(aPergs, "Pedido de Compra")
	
    For nX := 1 to Len(aPergs)

	    aAdd(aMvPar, { aPergs[nX], &("{|| Mv_Par" + StrZero(nX, 2) + " == 1 }") })
	
    next nX
    
	//carrega as perguntas criadas
	Pergunte(.F.)

Return

/*/{Protheus.doc} fErrorPar
//Gera um log quando ocorre error log
@author fabricio.reche
@since 07/08/2019
@version 1.0
@param e:ErrorStack, oLog, cOrigem, nS, oWSParCotacaoDTO
@type function
/*/
Static Function fErrorPar(cDescErro, cTabela, oLog, cOrigem, nS, oWSParCotacaoDTO, cChOri, cDifere, nT)
    Local nY, nX  := 0
    Local cItemWS := ''
    Local cPedWS  := ''
    Local aItens  := {}
    Local nTipo   := Iif(oLog:Funcao == 'RetornarPedidoLeilao', 1, 2)
    
    Default nS               := 0
    Default nT				 := 0
    Default oWSParCotacaoDTO := Nil
    Default cChOri           := ''
    Default cDifere          := ''
    
    If Empty(cDescErro)
    	cDescErro = MostraErro()
    EndIf
    lerro := .T.

	conout(PADR("ERROR LOG - " +PADR(ProcName(1),10) + " - Tempo " +FWTimeStamp(2) +" - ",60) + cDescErro)
	oLog:Retorno   := 99
	oLog:Origem    := IIf(Empty(cChOri), cOrigem, cChori)
	oLog:MsgLog    := 'ERROR LOG: ' + cDescErro
	oLog:SoapFault := 'ERROR LOG: ' + cDescErro
	oLog:Tstamp    := FwTimeStamp(3)
	oLog:Token     := 'ERROR LOG'
	oLog:DIfere    := cDifere
	oLog:SalvaObj(cTabela)
	oLog:novoLog()
	
	//libera o lock da rotina
	//lUnLockRot()
	dbSelectArea("ZP1")
	dbSetOrder(1)
	If nS > 0 .And. nTipo == 1
		
		For nX := nS To Len(oWSParCotacaoDTO)
			cItemWS := ''
			cPedWS  := oWSParCotacaoDTO[nX]:csCdPedidoWBC
			aItens  := oWSParCotacaoDTO[nX]:oWSlstPedidoItem:oWSParPedidoItemDTO
			For nY := 1 To Len(aItens)
				aEntrega := aItens[nY]:oWslstPedidoItemEntrega:oWSParPedidoItemEntregaDTO
				Iif(Empty(cItemWS), cItemWS := aItens[nY]:csCdItemWbc, (cItemWS += ';' + aItens[nY]:csCdItemWbc))
			Next nY
			
			RecLock("ZP1", .T.)
			ZP1->ZP1_FILIAL := xFilial('ZP1')
			ZP1->ZP1_TIPO   := nTipo
			ZP1->ZP1_CODPED := cPedWS
			ZP1->ZP1_ITPED  := cItemWS
			MsUnLock()
			
			//fHabiPed(nTipo, oWSParCotacaoDTO[nX]:csCdPedidoWBC, aPedWS, oLog)
		Next nX
	ElseIf  !Empty(oWSParCotacaoDTO) .And. nTipo == 2
		dbSelectArea("ZP1")
		dbSetOrder(1)
		//For nX := nS To Len(oWSParCotacaoDTO)
		cItemWS := ''
		cPedWS  := oWSParCotacaoDTO:csCdCotacaoWbc
		If Empty(nT)
			aItens := oWSParCotacaoDTO:oWSlstCotacaoItemDTO:oWSParCotacaoItemDTO
		Else
			aItens := oWSParCotacaoDTO:oWSlstCotacaoItemDTO:oWSParCotacaoItemDTO[nT]
		EndIf
		If !Empty(aItens)
			For nY := 1 To Len(aItens)
				IIf(Empty(cItemWS), cItemWS := aItens[nY]:csCdItemWbc, (cItemWS += ';' + aItens[nY]:csCdItemWbc))				
			Next nY
			
			RecLock("ZP1", .T.)
			ZP1->ZP1_FILIAL := xFilial('ZP1')
			ZP1->ZP1_TIPO   := nTipo
			ZP1->ZP1_CODPED := cPedWS
			ZP1->ZP1_ITPED  := cItemWS
			MsUnLock()
		EndIf
		//fHabiPed(nTipo, oWSParCotacaoDTO[nX]:csCdPedidoWBC, aPedWS, oLog)
		//Next nX
	EndIf
Return

/*/{Protheus.doc} fHabilita
//Gera um log quando ocorre error log
@author fabricio.reche
@since 07/2018
@version 1.0
@param ()
@type function
/*/
Static Function fHabilita()
    Local oLog   := FwParLog():New("PAR001", "fHabilita")
    Local aPedWS := {}
	
	dbSelectArea("ZP1")
	dbSetOrder(1)
	dbSeek(xFilial('ZP1'))
	While !ZP1->(EOF())		
		aPedWS := Separa(ZP1->ZP1_ITPED, ";", .F.)
		
		fHabiPed(ZP1->ZP1_TIPO, AllTrim(ZP1->ZP1_CODPED), aPedWS, oLog)
		
		RecLock("ZP1", .F.)
		dbDelete()
		MsUnLock()
		
		ZP1->(DbSkip())
	EndDo
Return


/*/{Protheus.doc} fHabiPed
//Habilita pedido
@author fabricio.reche
@since 07/08/2019
@version 1.0
@param nTipo, cPedWS, aPedWS, oLog
@type function
/*/
Static Function fHabiPed(nTipo, cPedWS, aPedWS, oLog)
    Local nX       := 0
	Local oCota    := Nil
	Local oCo      := Nil
	Local oCoIt    := Nil
	
	If nTipo == 1	// 1-leilao 
		oLog:Funcao := 'HabilitarRetornarLeilao'
		oLeilao := WSLeilao():New()
		oLe     := Leilao_ConfirmacaoNegociacaoDTO():New()
		oLe:csCdProcessoWbc     := cPedWS
		oLe:nnIdTipoProcesso    := nTipo   // 1-leilao 2-cotacao
		oLe:oWSlstConfirmacaoNegociacaoItemDTO := Leilao_ArrayOfConfirmacaoNegociacaoItemDTO():New()
		
		For nX := 1 To Len(aPedWS)
			oLeIt := Leilao_ConfirmacaoNegociacaoItemDTO():New()
			oLeIt:csCdProcessoItemWbc := aPedWS[nX]
			
			AADD(oLe:oWSlstConfirmacaoNegociacaoItemDTO:oWSConfirmacaoNegociacaoItemDTO, oLeIt)
		Next nX
		
		AADD(oLeilao:oWSlstConfirmacaoNegociacaoDTO:oWSConfirmacaoNegociacaoDTO, oLe:Clone())
		
		If !oLeilao:HabilitarRetornarLeilao()
			fSoapFault(oLog)
			conout(PADR("ERROR - " +PADR(ProcName(1),10) + " - Tempo " +FWTimeStamp(2) +" - ",60) + 'Erro no HabilitarRetornarLeilao()')
		EndIf
	Else
		oLog:Funcao := 'HabilitarRetornarCotacaoItem'
		oCota := WSParCotacao():New()
		oCota:oWSlstConfirmacaoNegociacaoDTO := Cotacao_ArrayOfConfirmacaoNegociacaoDTO():New()
		oCo   := Cotacao_ConfirmacaoNegociacaoDTO():New()
		oCo:csCdProcessoWbc     := cPedWS
		oCo:nnIdTipoProcesso    := nTipo   
		oCo:oWSlstConfirmacaoNegociacaoItemDTO := Cotacao_ArrayOfConfirmacaoNegociacaoItemDTO():New()
		
		For nX := 1 To Len(aPedWS)
			oCoIt := Cotacao_ConfirmacaoNegociacaoItemDTO():New()
			oCoIt:csCdProcessoItemWbc := aPedWS[nX]
			
			aAdd(oCo:oWSlstConfirmacaoNegociacaoItemDTO:oWSConfirmacaoNegociacaoItemDTO, oCoIt)
		Next nX
		
		aAdd(oCota:oWSlstConfirmacaoNegociacaoDTO:oWSConfirmacaoNegociacaoDTO, oCo:Clone())
		
		If !oCota:HabilitarRetornarCotacaoItem()
			fSoapFault(oLog)
			conout(PADR("ERROR - " +PADR(ProcName(1),10) + " - Tempo " +FWTimeStamp(2) +" - ",60) + 'Erro no HabilitarRetornarCotacaoItem()')
		EndIf
	EndIf
Return


/*/{Protheus.doc} fSoapFault
//Gera um log quando ocorre erro da chamada do metodo de um web service
@author fabricio.reche
@since 07/08/2019
@version 1.0
@param oLog, object, Objeto da classe FwParLog para gera??o de logs
@type function
/*/
Static Function fSoapFault(oLog)	
	Local cSvcError  := GetWSCError()  // Resumo do erro
	Local cSvcFCode  := GetWSCError(2) // Soap Fault Code
	Local cSvcFDescr := GetWSCError(3) // Soap Fault Description      

	lerro := .T.
	conout(" Erro na execucao da funcao " + oLog:Funcao)
	conout(cSvcError)

	If ! Empty(cSvcFCode)
		conout( "#" + AllTrim(cSvcFCode) + ": " + AllTrim(cSvcFDescr) )
	EndIf
	
	oLog:SalvaSoapFault(cSvcError, cSvcFCode, cSvcFDescr)
	oLog:novoLog()

Return             

/*/{Protheus.doc} fWsLogRet
//Gera log de retorna das chamadas dos m?todos do web service
@author fabri
@since 07/08/2019
@version 1.0
@param aRegDto, array, Array de retorno gen?rico
@param oLog, object, Objeto da classe FwParLog para gera??o de logs
@param cTabela, characters, Tabela para ser marcada como integrada
@param aReg, array, Lista de recnos que devem ser atualizados na tabela integrada
@type function
/*/
Static Function fWsLogRet(aRegDto, oLog, cTabela, aReg, nProc)      
 	Local nX      := 0
 	Local nY	  := 0
	Local cUpd    := ""
	Local cRegSav := ""
	Local cPrefix := ""
	Local aRecno  := {}
	
	Default cTabela := ""
	Default aReg    := {}

	cPrefix := PrefixoCpo(cTabela)

	for nX := 1 to Len(aRegDto)

		//reinicia o objeto para grava??o de v?rios registros
		oLog:NovoLog()

		conout("Origem: " + aRegDto[nX]:cScdOrigem)
		conout("Log: " + aRegDto[nX]:cSdsLog)
		conout("Token: " + aRegDto[nX]:cSnrToken)
		conout("Timestamp: " + aRegDto[nX]:cTdtLog)
		conout("ID Retorno: " + cValToChar( aRegDto[nX]:nNidRetorno ))
		conout("") //Quebra Linha

		nProc++
		
		//caso tenha tido sucesso na integra??o, guarda o recno para atualizar a tabela
		If aRegDto[nX]:nNidRetorno == 1
			If ! Empty(cTabela) .And. !Empty(aReg)
				If cTabela == 'PAO'
					For nY := 1 To Len(aReg)
						cRegSav += IIf(Empty(cRegSav), "", "/")
						cRegSav += cValToChar(aReg[nY])
					Next nY
				Else
					cRegSav += IIf(Empty(cRegSav), "", "/")
					cRegSav += cValToChar(aReg[nX])
				EndIf
				aAdd(aRecno, aReg[nX])
			EndIf
		Else
			lerro := .T.
		EndIf

		oLog:SalvaWbtLog(aRegDto[nX], cTabela)

	next nX
	
	aReg := aRecno

	If ! Empty(cRegSav)	
		
			cUpd := " update " + RetSqlName(cTabela)
			cUpd += " set " + cPrefix + "_XINTPA = " + ValToSql('1')
			If cTabela == 'SC1' 
				cUpd += " , C1_COTACAO = 'PORTAL' "
			EndIf
			cUpd += " where "  //D_E_L_E_T_ = ' '  
			cUpd += " R_E_C_N_O_ IN " + FormatIn(cRegSav, "/")
				
			If TcSqlExec(cUpd) < 0
				
				if ! IsBlind()
					Alert('erro: ' + TcSqlError())
				endIf
				
				conout("ERRO AO ATUALIZAR OS REGISTROS DA TABELA " +cTabela)
				conout(TcSqlError())
			Else
				TCSQLExec('COMMIT')
			EndIf

	EndIf

Return


/*/{Protheus.doc} fLogRetWs
//Gera log de retorna das chamadas dos m?todos do web service
@author fabricio.reche
@since 07/08/2019
@version 1.0
@param aRegDto, array, Array de retorno gen?rico
@param oLog, object, Objeto da classe FwParLog para gera??o de logs
@param cTabela, characters, Tabela para ser marcada como integrada
@param aPedidos, array, Lista de Pedidos que devem ser atualizados na tabela integrada
@type function
/*/
Static Function fLogRetWs(aRegDto, oLog, cTabela, cPedido, nProc, lCancel)      
	Local nX      := 0
	Local cUpd    := ""
	Local cPrefix := ""
	
	Default cTabela  := ""
	Default cPedido  := ""
	Default lCancel  := .F.
	
	cPrefix := PrefixoCpo(cTabela)

	for nX := 1 to Len(aRegDto)

		//reinicia o objeto para grava??o de v?rios registros
		oLog:NovoLog()
		
		conout("Origem: " + aRegDto[nX]:cScdOrigem)
		conout("Log: " + aRegDto[nX]:cSdsLog)
		conout("Token: " + aRegDto[nX]:cSnrToken)
		conout("Timestamp: " + aRegDto[nX]:cTdtLog)
		conout("ID Retorno: " + cValToChar( aRegDto[nX]:nNidRetorno ))
		conout("") //Quebra Linha

		nProc++
		
		//caso tenha tido sucesso na integra??o, guarda o recno para atualizar a tabela
		If aRegDto[nX]:nNidRetorno == 1
			If ! Empty(cTabela)
				
				cUpd := " update " + RetSqlName(cTabela)
				cUpd += " set " + cPrefix + "_XINTPA = " + ValToSql('1')
				cUpd += " where D_E_L_E_T_ = " + IIf(lCancel, "'*'", "' '")
				cUpd += "   and " + cPrefix + "_FILIAL = " + ValToSql(xFilial(cTabela)) 
				cUpd += "   and " + cPrefix + "_NUM    = " + ValToSql( RIGHT(cPedido, 6) )
				cUpd += "   and " + cPrefix + "_XINTPA != '1' " 
		
				If TcSqlExec(cUpd) < 0
					conout("ERRO AO ATUALIZAR OS REGISTROS DA TABELA " +cTabela)
					conout(TcSqlError())
				Else
					TCSQLExec('COMMIT')
				EndIf
			EndIf
		Else
			lerro := .T.
		EndIf

		oLog:SalvaWbtLog(aRegDto[nX], cTabela)

	next nX

Return

/*/{Protheus.doc} OPENSQL
//Faz a abertura de um alias tempor?rio
@author fabricio.reche
@since 07/08/2019
@version 1.0
@param _cAlias, characters, Alias a ser aberto 
@param _cQuery, characters, Consulta a ser utilizada
@type function
/*/
Static Function OPENSQL(_cAlias, _cQuery)

	CLOSESQL(_cAlias)

	_cQuery := ChangeQuery(_cQuery)

	DbUseArea(.T.,'TOPCONN',TCGenQry(,,_cQuery),_cAlias,.T.,.F.)

Return

/*/{Protheus.doc} CLOSESQL
//Efetua o fechamento do(s) Alias informados
@author fabricio.reche
@since 07/08/2019
@version 1.0
@param uAlias, undefined, Alias ou Array com alias a serem fechados
@type function
/*/
Static Function CLOSESQL(uAlias)      
	Local aAlias := IIf(Valtype(uAlias) == "A", uAlias, {uAlias})
	Local nX := 0
	
	for nX := 1 to Len(aAlias)
	       
		If Select(aAlias[nX]) <> 0
			DbSelectArea(aAlias[nX])
			DbCloseArea()
		EndIf
	
	next nX

Return

/*/{Protheus.doc} fIniLog
//Inicia o log da integra??o
@author fabricio.reche
@since 07/08/2019
@version 1.0
@param cIntegra, characters, descritivo do inicio da integra??o
@type function
/*/
Static Function fIniLog(cIntegra)

	Local cMsg := "Iniciando Integracao de " + cIntegra

	conout("")
	conout(">>> " + cMsg)

Return

/*/{Protheus.doc} fFimLog
//Finaliza o log
@author fabricio.reche
@since 07/08/2019
@version 1.0
@param cIntegra, characters, Descritivo do fim da integra??o
@type function
/*/
Static Function fFimLog(cIntegra)

	Local cMsg := "Fim " + cIntegra

	//conout("")
	conout("<<< " + cMsg)
	conout("")

Return

/*/{Protheus.doc} lMvPar
//VerIfica se a chave est? marcada para integra??o
@author fabricio.reche
@since 07/08/2019
@version 1.0
@Return lRet, Indica se a chave est? marcada nos parametros da rotina
@param cChave, characters, C?digo de busca
@type function
/*/
Static Function lMvPar(cChave)

	Local nPos := 0

	nPos := aScan(aMvPar, {|arr| cGeraChave(arr[1]) == cGeraChave(cChave) })

	If nPos > 0
		Return Eval(aMvPar[nPos][2])
	EndIf

Return .F.

/*/{Protheus.doc} cGeraChave
//Elimina caracteres para busca l?gica
@author fabricio.reche
@since 07/08/2019
@version 1.0
@Return cChave, Retorna a chave configurada
@param cChave, characters, C?digo de busca
@type function
/*/
Static Function cGeraChave(cChave)

	//deixa a chave sem acentos, caixa baixa e sem espa?os
	cChave := StrTran(cChave, " ", "")
	cChave := NoAcento(cChave)
	cChave := Lower(cChave)

Return cChave

/*/{Protheus.doc} SchedDef
//Fun??o para execu??o autom?tica via schedule
@author fabricio.reche                                                                              
@since 07/08/2019
@version 1.0
@Return aParam, par?metros de uso interno do schedule

@type function
/*/
Static Function SchedDef()

	Local aParam := {}

	aAdd(aParam, "P"     ) //P=Processo (R=Relat?rio)
	aAdd(aParam, "PAR001") //Grupo de perguntas
	aAdd(aParam, ""      ) //Alias (para relat?rios)
	aAdd(aParam, {}      ) //Ordena??es (para relat?rios)
	aAdd(aParam, "Integracao Protheus x Paradigma") //Descri??o do Processo/Relat?rio

Return aParam
                                                                             
/////////////////////////////////////////////////////////
// *************************************************** //
/////////////////////////////////////////////////////////
Static Function SetRegua1(oProcess, nLen)
        
	If ValType(oProcess) == "O"
		oProcess:SetRegua1(nLen)
	EndIf

	SysRefresh()

Return

/////////////////////////////////////////////////////////
// *************************************************** //
/////////////////////////////////////////////////////////
Static Function SetRegua2(oProcess, nLen)
        
	If ValType(oProcess) == "O"
		oProcess:SetRegua2(nLen)
	EndIf

	SysRefresh()

Return                              

/////////////////////////////////////////////////////////
// *************************************************** //
/////////////////////////////////////////////////////////
Static Function IncRegua2(oProcess, cMsg)
        
	If ValType(oProcess) == "O"
		oProcess:IncRegua2(cMsg)
	EndIf

	SysRefresh()

Return

/////////////////////////////////////////////////////////
// *************************************************** //
/////////////////////////////////////////////////////////
Static Function IncRegua1(oProcess, cMsg)

	If ValType(oProcess) == "O"
		oProcess:IncRegua1(cMsg)
	EndIf

	SysRefresh()

Return

/////////////////////////////////////////////////////////
// *************************************************** //
/////////////////////////////////////////////////////////
static function cGetCgcEmp(c_EmpFil)

	local cEmpBusca := SubStr(c_EmpFil, 1, 2)
	local cFilBusca := SubStr(c_EmpFil, 3, 2)
	local aDadosEmp := FwArrFilAtu( cEmpBusca, cFilBusca )

return aDadosEmp[18]

/////////////////////////////////////////////////////////
// *************************************************** //
/////////////////////////////////////////////////////////
static function m_vMoeda(nVa)
	local cRet
	cRet:= GetMv("MV_MOEDA"+cValToChar(nVa))


return cRet

/////////////////////////////////////////////////////////
// *************************************************** //
/////////////////////////////////////////////////////////
static function M_vSIMB(nVa) 

	local cRet
	cRet:= GetMv("MV_SIMB"+cValToChar(nX))

return cRet

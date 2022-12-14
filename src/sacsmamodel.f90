    !===============================================================================
    ! Modelo: Sacramento - Soil Moisture Accounting (SAC-SMA) Diário
    !===============================================================================
    SUBROUTINE sacsmamodel(ETp, CMB, Qin, Qout, N, Area, Params, Qbac)
    implicit none
    
    integer :: I, J, pt, N
    real*8, dimension(1000000) :: ETp, CMB, Qin, Qout, Qbac
    real*8 :: Params(16), Area

    !Parametros utilizados no modelo
    real*8 :: UZTWM, UZFWM, LZTWM, LZFPM, LZFSM, UZK, LZPK, LZSK
    real*8 :: PCTIM, ADIMP, ZPERC, REXP, PFREE, RIVA, RSERV, SIDE

    !Armazenamentos utilizados no modelo
    real*8 :: UZTWC, UZFWC, LZTWC, LZFPC, LZFSC, ADIMC

    !Fluxos da contabilidade da umidade do solo (SMA)
    real*8 :: E1, E2, E3, E4, E5, TWX, ROIMP, SUR, BF, PERC, DEL

    !Variáveis auxiliares
    real*8 :: RED, UZRAT, RATLZT, RATLZ, DEFR, FR, FI, CHECK
    real*8 :: ADSUR, ADDRO, RATIO, PERCM, PERCT, PERCF
    real*8 :: RATLP, RATLS, PERCP, PERCS, HPL
    real*8 :: EXCESS, SAVED, FRACP, BFP, BFS, TBF
    real*8 :: TCI, SURF, GRND, TET, EUSED, BFNCC, BFCC
    real*8 :: PREC, PET

    !Acumuladores dos valores dos escoamentos nos intervalos de tempo
    real*8 SBF, SSUR, SIF, SPERC, SDRO, SPBF
    real*8 S2BF, S2SUR, S2IF, S2DRO

    !Variávies do incremento de integração do modelo
    integer NINC
    real*8 DINC, PINC

    !Taxas de depleção de água por tempo do incremento
    real*8 DUZ, DLZP, DLZS

    !Outras variáveis do modelo
    real*8 PAREA, DT

    !Passando valores dos parâmetros para as variaveis utilizadas no modelo
    UZTWM = Params(01);    UZFWM = Params(02);    UZK   = Params(03);    ZPERC = Params(04)
    REXP  = Params(05);    LZTWM = Params(06);    LZFSM = Params(07);    LZFPM = Params(08)
    LZSK  = Params(09);    LZPK  = Params(10);    PFREE = Params(11);    PCTIM = Params(12)
    ADIMP = Params(13);    RIVA  = Params(14);    SIDE  = Params(15);    RSERV  = Params(16)

    !Inicializando armazenamentos
    UZTWC = UZTWM*0.5d0
    UZFWC = UZFWM*0.5d0
    LZTWC = LZTWM*0.5d0
    LZFPC = LZFPM*0.5d0
    LZFSC = LZFSM*0.5d0
    ADIMC = 0.d0
    
    SAVED = RSERV*(LZTWM+LZFPM+LZFSM)
    DT = 1.d0


    !SACRAMENTO - SOIL MOISTURE ACCOUTING
    DO J = 1, N

    !Area não impermeavel
    PAREA = 1.d0 - PCTIM - ADIMP
    
    !Precipitação e evapotranspiração potencial
    PET = ETp(J)
    PREC = CMB(J)


    !Calculando a perda por evapotranspiração, na zona superior, no intervalo
    ! PET = Evapotranspiração potencial (mm)
    ! RED = Diferença entre a PET e evapotranspiração ocorrida no intervalo (mm)
    ! E1  = Evaporação ocorrida na zona de tensao superior (mm)
    ! E2  = Evaporação ocorrida na zona livre superior (mm)
    ! UZRAT = Fracao de agua em toda a zona superior
    E1 = PET * (UZTWC/UZFWM)
    RED = PET - E1

    !Descontando a evaporação da zona de tensão superior, porém não pode ser evaporada mais água do que há nesta camada.
    UZTWC = UZTWC - E1
    E2 = 0.d0
    if (UZTWC.ge.0.d0) go to 220
    !E1 não pode exceder UZTWC
    E1 = E1 + UZTWC                                             !UZTWC(negativo) = UZTWC(real) - E1
    UZTWC = 0.d0
    RED = PET - E1

    !Descontando o resíduo da PET na zona livre superior
    if (UZFWC.ge.RED) go to 221
    !Se RED é maior que UZFWC, E2 não pode exceder a quantidade de água na zona livre superior.
    E2 = UZFWC
    UZFWC = 0.d0
    RED = RED - E2
    go to 225
    !Se UZFWC é maior que (PET - E1) = RED, desconta-se todo o resíduo na zona livre superior.
221 continue
    E2 = RED
    UZFWC = UZFWC - E2
    RED = 0.d0

    !Verificando demanda de água pela zona de tensao superior
220 continue
    if ((UZTWC/UZTWM).ge.(UZFWC/UZFWM)) go to 225
    !Fração da água na zona livre superior excedeu a fração na zona de tensão superior, então transfere-se água
    !da zona livre para a de tensão.
    UZRAT = (UZTWC + UZFWC) / (UZTWM + UZFWM)
    UZTWC = UZRAT * UZTWM
    UZFWC = UZRAT * UZFWM

    !Verificando se os armazenamentos da zona superior secaram
225 continue
    if (UZTWC.lt.1.d-6) UZTWC = 0.d0
    if (UZFWC.lt.1.d-6) UZFWC = 0.d0


    !Calculando a perda por evapotranspiração, na zona inferior, no intervalo
    ! E3  = Evaporação ocorrida na zona de tensao inferior (mm)
    ! RATLZT = Fração de água na zona de tensão inferior
    ! RATLZ  = Fração de água em toda a zona inferior
    ! DEL = Coluna de água transferida da zona livre para a zona de tensão

    E3 = RED * (LZTWC / (UZTWM + LZTWM))

    !Descontando a evaporação da zona de tensão inferior
    LZTWC = LZTWC - E3
    if (LZTWC.GE.0.d0) go to 226
    !E3 não pode exceder o armazenamento da zona de tensão inferior
    E3 = E3 + LZTWC                                             !LZTWC(negativo) = LZTWC(real) - E3
    LZTWC = 0.d0

    !Verificando demanda de agua pela zona de tensão inferior
226 continue
    RATLZT = LZTWC / LZTWM
    RATLZ = (LZTWC+LZFPC+LZFSC-SAVED)/(LZTWM+LZFPM+LZFSM-SAVED)
    if (RATLZT.ge.RATLZ) go to 230
    !Recarregando a zona de tensão inferior com água da zona livre inferior, se houver mais água lá.
    DEL = (RATLZ-RATLZT) * LZTWM
    !Transfere água da zona livre inferior suplementar (LZFSC) para a zona de tensão inferior (LZTWC)
    LZTWC = LZTWC + DEL
    LZFSC = LZFSC - DEL
    if (LZFSC.ge.0.d0) go to 230
    !Se a transferência excedeu LZFSC então o resto vem da zona livre inferior primária (LZFPC)
    LZFPC = LZFPC + LZFSC
    LZFSC = 0.d0

    !Verificando se o armazenamento da LZFSC secou
230 continue
    if (LZTWC.lt.1.d-6) LZTWC = 0.d0


    !Calculando a perda por evapotranspiração da zona impermeavel no intervalo
    ! E5  = Evaporação ocorrida na zona impermeavel (mm)

    E5 = E1 + (RED + E2) * ( (ADIMC-E1-UZTWC) / (UZTWM+LZTWM) )

    !Descontando a evaporação do armazenamento da área impermeável
    ADIMC = ADIMC - E5
    if (adimc.ge.0.d0) go to 231
    !E5 não pode exceder o armazenamento da área impermeável
    E5 = E5 + ADIMC                                             !ADIMC(negativo) = ADIMC(real) - E5
    ADIMC = 0.d0

    !Determinando fração do volume da evapotranspiração na área impermeavel, relativo a toda a evapotranspiração
    !ocorrida na bacia.
231 continue
    E5 = E5 * ADIMP



    !Calculando os escoamentos de percolação e superficial.
    ! TWX   = Umidade em excesso na zona de tensão superior, no intervalo (mm)
    ! ROIMP = Escoamento superficial da área impermeável

    TWX = PREC + UZTWC - UZTWM

    if (TWX.ge.0.d0) go to 232
    !Se não houve excesso de água na zona de tensão superior...
    UZTWC = UZTWC + PREC
    TWX = 0.d0
    go to 233

    !Umidade disponível (água que não infiltrou) na zona de tensão superior, vai para o armazenamento da zona impermeavel.
232 continue
    UZTWC = UZTWM
233 continue
    ADIMC = ADIMC + PREC - TWX

    !Calculando o escoamento superficial da área impermeável
    ROIMP = PREC * PCTIM



    !Inicializando acumuladores do intervalo DT
    SBF = 0.d0;           S2BF = 0.d0                           !Escoamento de base
    SSUR = 0.d0;          S2SUR = 0.d0                          !Escoamento superficial
    SIF = 0.d0;           S2IF = 0.d0                           !Escoamento interno (subsuperficial)
    SPERC = 0.d0                                                !Percolação
    SDRO = 0.d0;          S2DRO = 0.d0                          !Run-off direto
    SPBF = 0.d0                                                 !Escoamento de base da zona livre inferior primária

    !Determinando os incrementos computacionais de tempo para o intervalo básico de tempo.
    !Nenhum incremento irá exceder 5.0 milimetros de UZFWC+PAV.
    ! NINC = Número de incrementos de tempo em que o intervalo de tempo será dividido para posterior contabilidade
    !        da umidade do solo.
    ! DINC = Comprimento de cada incremento em dias
    ! PINC = Quantidade de umidade disponível para cada incremento
    ! QIN  = Vazão montante, transformada em milimetro por tempo de incremento
    NINC = 1.d0 + 0.2d0*(UZFWC+TWX)
    DINC = (1.d0/NINC)*DT
    PINC = TWX/NINC

    !Calculando frações de deplecionamento da água para o tempo de incremento, sendo que as taxas de depleção são
    !para um dia.
    ! DUZ  = Depleção de água da zona superior, por incremento
    ! DLZP  = Depleção de água da zona inferior primária, por incremento
    ! DLZS  = Depleção de água da zona inferior suplementar, por incremento

    DUZ  = 1.d0 - ( (1.d0-UZK)**DINC )
    DLZP = 1.d0 - ( (1.d0-LZPK)**DINC )
    DLZS = 1.d0 - ( (1.d0-LZSK)**DINC )



! +--------------------------------------------------------------------------------------------+
! |       INICIANDO CICLO DE INTEGRAÇÃO PARA CADA INCREMENTO, PARA O INTERVALO DE TEMPO        |
! +--------------------------------------------------------------------------------------------+
    DO 240 I = 1, NINC

    ADSUR = 0.d0

    !Calculando escoamento superficial direto (da área impermeável)
    !ADDRO = Volume(coluna) de escomanto superficial direto da área impermeável
    RATIO = (ADIMC-UZTWC) / LZTWM
    if (RATIO.lt.0.d0) RATIO = 0.d0
    ADDRO = PINC * (RATIO**2)


    !Calculando o escoamento de base da zona livre inferior primária e o acumulado do intervalo de tempo
    !BF    = Escoamento de base
    BF = LZFPC * DLZP
    LZFPC = LZFPC - BF
    if (LZFPC.gt.1.d-4) go to 234
    !O escoamento de base não pode exceder o armazenamento da zona livre inferior primária
    BF = BF + LZFPC                                             !LZFPC(negativo) = LZFPC(real) - BF
    LZFPC = 0.d0
    !Acumulando o escoamento de base de toda a zona livre inferior, e da zona livre inferior primária
234 continue
    SBF = SBF + BF
    SPBF = SPBF + BF

    !Calculando o escoamento de base da zona livre inferior suplementar e o acumulado do intervalo de tempo
    BF = LZFSC * DLZS
    LZFSC = LZFSC - BF
    if(LZFSC.gt.1.d-4) go to 235
    !Escoamento de base não pode exceder o armazenamento da zona livre inferior suplementar
    BF = BF + LZFSC                                             !LZFSC(negativo) = LZFSC(real) - BF
    LZFSC = 0.d0
    !Acumulando o escoamento de base de toda a zona livre inferior
235 continue
    SBF = SBF + BF


    !Calculando o volume percolado (se não houver água disponível, pula esta etapa)
    ! PERC = Volume percolado no incremento de tempo
    ! DEFR = Taxa de deficiência de umidade da zona inferior do solo
    ! FR   = Mudança na retirada de água pela percolação devido ao solo congelado
    ! FI   = Mudança no escoamento interno devido ao solo congelado
    if ((PINC+UZFWC).gt.0.01d0) go to 251
    UZFWC = UZFWC + PINC
    go to 249
    !Há água, calculando percolação:
251 continue
    PERCM = LZFPM * DLZP + LZFSM * DLZS
    PERC = PERCM * (UZFWC/UZFWM)
    DEFR = 1.d0 - ((LZTWC+LZFPC+LZFSC) / (LZTWM+LZFPM+LZFSM))
    FR = 1.d0
    FI = 1.d0
    PERC = PERC * ( 1.d0 + ZPERC * (DEFR**REXP) ) * FR
    !OBS: A percolação ocorre da zona livre superior antes do PAV ser adicionado
    if (PERC.lt.UZFWC) go to 241
    !Percolação não pode exceder o armazenamento da zona livre superior
    PERC = UZFWC

    !Se a percolação for menor que UZFWC
241 continue
    UZFWC = UZFWC - PERC

    !Verifica se a percolação excedeu a deficiência da zona inferior
    CHECK = LZTWC + LZFPC + LZFSC + PERC - LZTWM - LZFPM - LZFSM
    if (CHECK.le.0.d0) go to 242
    !Volume dos armazenamentos das zonas inferiores mais percolação não deve exceder a capacidade máxima da zona inferior.
    PERC = PERC - CHECK
    !Devolvendo excesso à zona superior
    UZFWC = UZFWC + CHECK
    !Acumulando a percolação dos incrementos
242 continue
    SPERC = SPERC + PERC


    !Calculando o escoamento interno e o acumulado
    ! DEL = Escoamento interno
    !OBS: A quantidade PINC ainda não foi adicionada
    DEL = UZFWC * DUZ * FI
    SIF = SIF + DEL
    UZFWC = UZFWC - DEL


    !Distribui-se a água percolada entre as zonas inferiores, sendo que a zona de tensão deve ser preenchida antes
    !com excessão da percolação ocorrida na área PFREE.
    ! PERCT = Percolação que vai para a zona de tensão inferior
    ! PERCF = Percolação que vai direto para a zona livre inferior
    ! HPL = Tamanho relativo do armazenamento primário comparado com o armazenamento livre inferior total
    ! RATLP = Fração de preenchimento da zona livre inferior primária
    ! RATLS = Fração de preenchimento da zona livre inferior suplementar
    ! FRACP = Fração da percolação que vai para zona livre primária
    ! PERCP = Quantidade do excesso de percolação que vai para a zona livre primária
    ! PERCS = Quantidade do excesso de percolação que vai para a zona livre suplementar
    ! EXCESS = Eventual excesso da capacidade máxima da zona livre inferior primária

    PERCT = PERC * (1.d0-PFREE)
    if ((PERCT+LZTWC).gt.LZTWM) go to 243
    !Zona de tensão inferior recebe água percolada
    LZTWC = LZTWC + PERCT
    PERCF = 0.d0
    go to 244
    !Calculando água que irá direto para a zona livre inferior
243 continue
    PERCF = PERCT + LZTWC - LZTWM
    LZTWC = LZTWM

    !Distribui-se a água percolada em excesso da necessidade da zona de tensão entre os armazenamentos de água livre.
244 continue
    PERCF = PERCF + PERC * PFREE
    if (PERCF.eq.0.d0) go to 245
    !Distribuindo percolação
    HPL = LZFPM / (LZFPM+LZFSM)
    RATLP = LZFPC / LZFPM
    RATLS = LZFSC / LZFSM
    FRACP = (HPL * 2.d0 * (1.d0-RATLP)) / ((1.d0-RATLP) + (1.d0-RATLS))
    if (FRACP.gt.1.d0) FRACP = 1.d0
    PERCP = PERCF * FRACP
    PERCS = PERCF - PERCP
    !Adicionando o excesso de percolação na zona suplementar
    LZFSC = LZFSC + PERCS
    if (LZFSC.le.LZFSM) go to 246
    !A adição do excesso da percolação não pode exceder a capacidade máxima da zona livre suplementar
    PERCS = PERCS - LZFSC + LZFSM                               !LZFSC(excesso) = LZFSC(real) + PERCS
    LZFSC = LZFSM

    !Adicionando o excesso de percolação na zona primária
246 continue
    LZFPC = LZFPC + (PERCF - PERCS)

    !Verificar para ter certeza que o armazenamento livre primário não excedeu a capacidade máxima
    if (LZFPC.le.LZFPM) go to 245
    EXCESS = LZFPC - LZFPM
    LZTWC = LZTWC + EXCESS
    LZFPC = LZFPM


    !Distribuir PINC entre a zona superior livre e escoamento superficial
245 continue
    if (PINC.eq.0.d0) go to 249
    !Verificar se o acréscimo de PINC excede a capacidade máxima da zona livre superior
    if ((PINC+UZFWC).gt.UZFWM) go to 248
    !Não excedeu, ou seja, toda a água infiltra, logo não haverá escoamento superficial
    UZFWC = UZFWC + PINC
    go to 249


    !Calcular o escoamento superficial e a soma dos incrementos
    ! SUR   = Escoamento superficial
    ! ADSUR = Quantidade do escoamento direto que provém da porção ADIMP que não está gerando escoamento superficial
    !         direto no momento
    ! ADDRO/PINC = Fração da área impermeável (ADIMP) que está gerando escoamento superficial direto no momento
248 continue
    SUR = PINC + UZFWC - UZFWM
    UZFWC = UZFWM
    SSUR = SSUR + SUR*PAREA
    ADSUR = SUR * (1.d0 - ADDRO/PINC)
    SSUR = SSUR + ADSUR*ADIMP


    !Balanço de água da área impermeável
249 continue
    ADIMC = ADIMC + PINC - ADDRO - ADSUR
    if (ADIMC.le.(UZTWM+LZTWM)) go to 247
    ADDRO = ADDRO + ADIMC - (UZTWM + LZTWM)
    ADIMC = UZTWM + LZTWM
    !Acumulando escoamento superficial direto do incremento
247 continue
    SDRO = SDRO + ADDRO * ADIMP
    if (ADIMC.lt.1.d-6) ADIMC = 0.d0


    !Passa valores acumulados para variaveis secundárias
    S2BF = SBF
    S2DRO = SDRO
    S2SUR = SSUR
    S2IF = SIF


240 CONTINUE 
! +-----------------------------------------------------------------------------------------+
! |       FIM DO CICLO DE INTEGRAÇÃO PARA CADA INCREMENTO, PARA O INTERVALO DE TEMPO        |
! +-----------------------------------------------------------------------------------------+



    !Calcula os acumulados e ajusta a quantidade de run-off pela área em que ele foi gerado
    ! EUSED = Evaporação ocorrida na fração de área PAREA, durante o intervalo de tempo
    EUSED = E1 + E2 + E3
    SIF = SIF * PAREA

    !Separando componente do escoamento de base que vai para o canal, da componente que não vai para o canal
    ! TBF = é o escoamento de base total
    ! BFCC = componente do escoamento de base que vai para o canal
    ! BFNCC = componente do escoamento de base que NÃO vai para o canal
    TBF = SBF * PAREA
    BFCC = TBF * SIDE
    BFP = SPBF * PAREA * SIDE
    BFS = BFCC - BFP
    if (BFS.lt.0.d0) BFS = 0.d0
    BFNCC = TBF - BFCC

    !Calculando escoamento afluente da bacia para o canal no intervalo de tempo
    ! TCI  = Escoamento afluente total
    ! GRND = Escoamento subterrâneo
    ! SURF = Escoamento superficial
    TCI = ROIMP + SDRO + SSUR + SIF + BFCC
    GRND = SIF + BFCC   ! interflow is part of ground flow
    SURF = TCI - GRND

    !Calcula da evapotranspiração da vegetação ciliar
    ! E4 = Evapotranspiração da mata ciliar (mm)
    E4 = (PET - EUSED) * RIVA

    !Subtrai a evapotranspiração da mata ciliar do escoamento afluente para o canal
    TCI = TCI - E4
    if (TCI.GE.0.d0) go to 250
       E4 = E4 + TCI
       TCI = 0.d0
250 continue
    GRND = GRND - E4
    if (GRND.LT.0.d0) then
       SURF = SURF + GRND
       GRND = 0.d0
       if (SURF.LT.0.d0) SURF = 0.d0
    end if

    !Calcula a evapotranspiração total que ocorreu efetivamente
    ! TET = Evapotranspiração total ocorrida (mm)
    EUSED=EUSED*PAREA
    TET = EUSED + E5 + E4

    !Verifica se armazenamento da área impermeável é maior que da zona de tensão superior
    if (ADIMC.LT.UZTWC) ADIMC = UZTWC

    Qbac(J) = TCI
    END DO

    END SUBROUTINE sacsmamodel

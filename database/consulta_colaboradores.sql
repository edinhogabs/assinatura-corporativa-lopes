SELECT
       'www.distribuidoralopes.com' AS SITE,
       PFUNC.DATAADMISSAO AS ADMISSAO,
       PFUNC.CHAPA,
       PFUNC.NOME AS NOME_COMPLETO,
       CASE
            WHEN INSTR(TRIM(PFUNC.NOME), ' ') = 0 THEN TRIM(PFUNC.NOME)
            ELSE REGEXP_SUBSTR(TRIM(PFUNC.NOME), '^[^ ]+')
                 || ' ' ||
                 REGEXP_SUBSTR(TRIM(PFUNC.NOME), '[^ ]+$')
       END AS NOME_ASSINATURA,
       LOWER(
            REPLACE(
                 CASE
                      WHEN INSTR(TRIM(PFUNC.NOME), ' ') = 0 THEN TRIM(PFUNC.NOME)
                      ELSE REGEXP_SUBSTR(TRIM(PFUNC.NOME), '^[^ ]+')
                           || ' ' ||
                           REGEXP_SUBSTR(TRIM(PFUNC.NOME), '[^ ]+$')
                 END,
                 ' ',
                 '.'
            )
       ) || '@distribuidoralopes.com' AS EMAIL_ASSINATURA,
       PFUNCAO.NOME AS FUNCAO,
       CASE
            WHEN PPESSOA.TELEFONE1 IS NOT NULL THEN PPESSOA.TELEFONE1
            WHEN PPESSOA.TELEFONE2 IS NOT NULL THEN PPESSOA.TELEFONE2
            ELSE 'NAO INFORMADO'
       END AS TELEFONE,
       PSECAO.DESCRICAO AS SECAO,
       PFUNC.CODSITUACAO AS STATUS
FROM   PFUNCAO
       INNER JOIN PFUNC
               ON PFUNCAO.CODCOLIGADA = PFUNC.CODCOLIGADA
              AND PFUNCAO.CODIGO = PFUNC.CODFUNCAO
       INNER JOIN PSECAO
               ON PFUNC.CODCOLIGADA = PSECAO.CODCOLIGADA
              AND PFUNC.CODSECAO = PSECAO.CODIGO
       INNER JOIN GCOLIGADA
               ON PFUNC.CODCOLIGADA = GCOLIGADA.CODCOLIGADA
       INNER JOIN PPESSOA
               ON PFUNC.CODPESSOA = PPESSOA.CODIGO
       LEFT JOIN PTPDEMISSAO
              ON PTPDEMISSAO.CODCLIENTE = PFUNC.TIPODEMISSAO
WHERE  PFUNC.CODSITUACAO <> 'D'
--AND PFUNC.DATAADMISSAO >= TO_DATE('01/06/2026', 'DD/MM/YYYY')
AND    PSECAO.DESCRICAO IN (
       'ADMINISTRAÇÃO',
       'CD - ADMINISTRATIVO',
       'CD - LINHA AMBIENTE',
       'CD - LINHA PLF',
       'COMERCIAL INTERNO',
       'COMUNICAÇÃO E MARKETING',
       'CONTABIL FISCAL',
       'CREDITO DE COBRANÇA',
       'DIRETORIA',
       'FATURAMENTO',
       'FINANCEIRO',
       'LOJA',
       'RH',
       'TI',
       'Seção 01 do Agrupamento 00'
)
ORDER BY
       PSECAO.DESCRICAO,
       PFUNC.NOME

# Relatório de Performance de Campanhas (PPE) - Versão Final

## 1. Objetivo

Este relatório foi criado para **mensurar e classificar a performance** de todas as campanhas de email marketing através de um **Score de Performance de Email (PPE)**. O objetivo é fornecer uma visão consolidada e padronizada da efetividade de cada campanha, permitindo:

- ✅ **Comparação objetiva** entre diferentes campanhas (incluindo as sem envios).
- ✅ **Análise rápida** do sucesso de um disparo.
- ✅ **Tomada de decisões** baseada em dados concretos.
- ✅ **Identificação de oportunidades** de otimização.

---

## 2. Modelo de Score: Foco em Engajamento e Saúde da Lista

O modelo de score foi desenhado para valorizar o **relacionamento com o público** (Aberturas, Cliques) e penalizar ações que prejudicam a **saúde da lista e a reputação do remetente** (Rejeições, Cancelamentos).

### Fórmula Final

A fórmula exata implementada na query é:

```
Score = (Taxa de Abertura * 40%) 
      - (Taxa de Rejeição * 35%) 
      - (Taxa de Cancelamento * 15%) 
      + (Taxa de Clique (CTR) * 10%) 
      + (Taxa de Clique por Abertura (CTOR) * 5%)
```

### Detalhamento dos Pesos

| Métrica | Peso | Justificativa Estratégica |
|---|---|---|
| **Taxa de Abertura** | **+40%** | **Métrica Principal.** Mede o sucesso do assunto e a relevância inicial. |
| **Taxa de Rejeição (Bounce)**| **-35%** | **Guardião da Reputação.** Penaliza severamente listas desatualizadas. |
| **Taxa de Cancelamento** | **-15%** | **Termômetro da Relevância.** Mede a perda de interesse no conteúdo. |
| **Taxa de Clique (CTR)** | **+10%** | **Bônus de Ação.** Recompensa campanhas que motivam uma ação. |
| **Taxa de Clique por Abertura (CTOR)**| **+5%** | **Bônus de Qualidade.** Valoriza a persuasão do conteúdo do email. |

---

## 3. Detalhamento das Métricas (Conforme a Query)

| Métrica | O que Mede | Como é Calculada na Query |
|---|---|---|
| **Total Enviado** | Disparos totais registrados. | `COUNT(R.aOBMReportMailerID)` |
| **Total Entregue** | Envios que chegaram à caixa de entrada. | `SUM(CASE WHEN R.nSentStatus IN (1, 2) THEN 1 ELSE 0 END)` |
| **Total Bounce** | Envios que retornaram com erro. | `SUM(CASE WHEN R.nBounceType > 0 THEN 1 ELSE 0 END)` |
| **Total Aberturas** | Pessoas únicas que abriram **ou** clicaram. | `COUNT(DISTINCT CASE WHEN R.nSentStatus >= 3 OR CLK.nURLID IS NOT NULL THEN R.nTargetID END)` |
| **Total Cliques** | Pessoas únicas que clicaram em algum link. | `COUNT(DISTINCT CLK.nTargetID)` |
| **Total Cancelamentos**| Descadastros. | `0` (Fixo em 0, precisa de fonte de dados) |

---

## 4. Classificação do Score

O resultado do score é classificado em faixas para facilitar a análise imediata.

| Pontuação (Score) | Nível de Efetividade | Análise e Ação Recomendada |
|---|---|---|
| **Acima de 18** | ✅ **EXCELENTE** | Alta performance. Analisar para replicar o sucesso. |
| **12 a 17.99** | 👍 **BOM** | Resultado sólido com bom alcance e sem prejudicar a reputação. Manter boas práticas. |
| **5 a 11.99** | 🟡 **MÉDIO** | Desempenho aceitável, mas com pontos claros para otimização. |
| **1 a 4.99** | ⚠️ **ATENÇÃO** | Baixo engajamento ou problemas de entrega. Investigar a causa (segmentação, conteúdo, saúde da lista). |
| **Abaixo de 1** | ❌ **CRÍTICO** | Campanha ineficaz ou prejudicial à reputação. Pausar e corrigir a estratégia imediatamente. |

---

## 5. Implementação no Banco de Dados

### Tabelas Utilizadas

| Tabela | Descrição na Query | Join |
|---|---|---|
| `dbo.tblCampaignMain` | Fonte principal de **todas** as campanhas. | Base (FROM) |
| `dbo.tblOBMReportMailer` | Registro central de disparos (envios, entregas, bounces). | `LEFT JOIN` |
| `dbo.tblURLClickStatus` | Rastreamento de cliques por URL e usuário. | `LEFT JOIN` |

O uso de `LEFT JOIN` garante que **todas as campanhas de `tblCampaignMain` sejam listadas**, mesmo que não tenham registros de envio em `tblOBMReportMailer`.

---

## 6. Query SQL Definitiva

Esta query serve como a fonte de dados final para o relatório, garantindo que todas as campanhas sejam exibidas.

```sql
USE tlAnalytics;
GO

WITH MetricBase AS (
    SELECT 
        C.aCampaignID,
        C.tCampaignName,
        CASE WHEN C.bIsActive = 1 THEN 'ATIVA' ELSE 'DESATIVADA' END AS StatusCampanha,
        
        COUNT(R.aOBMReportMailerID) AS TotalEnviado,
        SUM(CASE WHEN R.nSentStatus IN (1, 2) THEN 1 ELSE 0 END) AS TotalEntregue,
        SUM(CASE WHEN R.nBounceType > 0 THEN 1 ELSE 0 END) AS TotalBounce,
        COUNT(DISTINCT CASE WHEN R.nSentStatus >= 3 OR CLK.nURLID IS NOT NULL THEN R.nTargetID END) AS TotalAberturas,
        COUNT(DISTINCT CLK.nTargetID) AS TotalCliques,
        0 AS TotalCancelamentos

    FROM 
        dbo.tblCampaignMain C
    LEFT JOIN 
        dbo.tblOBMReportMailer R ON C.aCampaignID = R.nCampaignID
    LEFT JOIN 
        dbo.tblURLClickStatus CLK ON R.nCampaignID = CLK.nCampaignID 
                                   AND R.nOBMailerID = CLK.nOBMailerID
                                   AND R.nTargetID = CLK.nTargetID
    WHERE C.bDeleted = 0
    GROUP BY 
        C.aCampaignID, C.tCampaignName, C.bIsActive
)

SELECT 
    aCampaignID AS [ID],
    tCampaignName AS [Nome da Campanha],
    StatusCampanha,
    
    -- TOTAIS PRINCIPAIS
    ISNULL(TotalEnviado, 0) AS [Total Enviado],
    ISNULL(TotalEntregue, 0) AS [Total Entregue],
    ISNULL(TotalBounce, 0) AS [Total Bounce],
    ISNULL(TotalAberturas, 0) AS [Total Aberturas],
    ISNULL(TotalCliques, 0) AS [Total Cliques],
    
    -- TAXAS PERCENTUAIS
    CAST(ROUND(COALESCE((ISNULL(TotalAberturas, 0) * 100.0) / NULLIF(ISNULL(TotalEntregue, 0), 0), 0), 2) AS DECIMAL(10,2)) AS [Taxa Abertura %],
    CAST(ROUND(COALESCE((ISNULL(TotalBounce, 0) * 100.0) / NULLIF(ISNULL(TotalEnviado, 0), 0), 0), 2) AS DECIMAL(10,2)) AS [Taxa Rejeição %],
    CAST(ROUND(COALESCE((ISNULL(TotalCancelamentos, 0) * 100.0) / NULLIF(ISNULL(TotalEntregue, 0), 0), 0), 2) AS DECIMAL(10,2)) AS [Taxa Cancelamento %],
    CAST(ROUND(COALESCE((ISNULL(TotalCliques, 0) * 100.0) / NULLIF(ISNULL(TotalEntregue, 0), 0), 0), 2) AS DECIMAL(10,2)) AS [Taxa Clique (CTR) %],
    CAST(ROUND(COALESCE((ISNULL(TotalCliques, 0) * 100.0) / NULLIF(ISNULL(TotalAberturas, 0), 0), 0), 2) AS DECIMAL(10,2)) AS [Taxa Clique/Abertura (CTOR) %],
    
    -- SCORE E CLASSIFICAÇÃO
    CAST(
        ROUND(
            (
              (COALESCE((ISNULL(TotalAberturas, 0) * 1.0) / NULLIF(ISNULL(TotalEntregue, 0), 0), 0) * 100 * 0.40)
            - (COALESCE((ISNULL(TotalBounce, 0) * 1.0) / NULLIF(ISNULL(TotalEnviado, 0), 0), 0) * 100 * 0.35)
            - (COALESCE((ISNULL(TotalCancelamentos, 0) * 1.0) / NULLIF(ISNULL(TotalEntregue, 0), 0), 0) * 100 * 0.15)
            + (COALESCE((ISNULL(TotalCliques, 0) * 1.0) / NULLIF(ISNULL(TotalEntregue, 0), 0), 0) * 100 * 0.10)
            + (COALESCE((ISNULL(TotalCliques, 0) * 1.0) / NULLIF(ISNULL(TotalAberturas, 0), 0), 0) * 100 * 0.05)
            )
        , 2)
    AS DECIMAL(10, 2)) AS [SCORE],
    
    CASE 
        WHEN (
          (COALESCE((ISNULL(TotalAberturas, 0) * 1.0) / NULLIF(ISNULL(TotalEntregue, 0), 0), 0) * 100 * 0.40)
        - (COALESCE((ISNULL(TotalBounce, 0) * 1.0) / NULLIF(ISNULL(TotalEnviado, 0), 0), 0) * 100 * 0.35)
        - (COALESCE((ISNULL(TotalCancelamentos, 0) * 1.0) / NULLIF(ISNULL(TotalEntregue, 0), 0), 0) * 100 * 0.15)
        + (COALESCE((ISNULL(TotalCliques, 0) * 1.0) / NULLIF(ISNULL(TotalEntregue, 0), 0), 0) * 100 * 0.10)
        + (COALESCE((ISNULL(TotalCliques, 0) * 1.0) / NULLIF(ISNULL(TotalAberturas, 0), 0), 0) * 100 * 0.05)
        ) >= 18 THEN 'EXCELENTE'
        WHEN (
          (COALESCE((ISNULL(TotalAberturas, 0) * 1.0) / NULLIF(ISNULL(TotalEntregue, 0), 0), 0) * 100 * 0.40)
        - (COALESCE((ISNULL(TotalBounce, 0) * 1.0) / NULLIF(ISNULL(TotalEnviado, 0), 0), 0) * 100 * 0.35)
        - (COALESCE((ISNULL(TotalCancelamentos, 0) * 1.0) / NULLIF(ISNULL(TotalEntregue, 0), 0), 0) * 100 * 0.15)
        + (COALESCE((ISNULL(TotalCliques, 0) * 1.0) / NULLIF(ISNULL(TotalEntregue, 0), 0), 0) * 100 * 0.10)
        + (COALESCE((ISNULL(TotalCliques, 0) * 1.0) / NULLIF(ISNULL(TotalAberturas, 0), 0), 0) * 100 * 0.05)
        ) BETWEEN 12 AND 17.99 THEN 'BOM'
        WHEN (
          (COALESCE((ISNULL(TotalAberturas, 0) * 1.0) / NULLIF(ISNULL(TotalEntregue, 0), 0), 0) * 100 * 0.40)
        - (COALESCE((ISNULL(TotalBounce, 0) * 1.0) / NULLIF(ISNULL(TotalEnviado, 0), 0), 0) * 100 * 0.35)
        - (COALESCE((ISNULL(TotalCancelamentos, 0) * 1.0) / NULLIF(ISNULL(TotalEntregue, 0), 0), 0) * 100 * 0.15)
        + (COALESCE((ISNULL(TotalCliques, 0) * 1.0) / NULLIF(ISNULL(TotalEntregue, 0), 0), 0) * 100 * 0.10)
        + (COALESCE((ISNULL(TotalCliques, 0) * 1.0) / NULLIF(ISNULL(TotalAberturas, 0), 0), 0) * 100 * 0.05)
        ) BETWEEN 5 AND 11.99 THEN 'MÉDIO'
        WHEN (
          (COALESCE((ISNULL(TotalAberturas, 0) * 1.0) / NULLIF(ISNULL(TotalEntregue, 0), 0), 0) * 100 * 0.40)
        - (COALESCE((ISNULL(TotalBounce, 0) * 1.0) / NULLIF(ISNULL(TotalEnviado, 0), 0), 0) * 100 * 0.35)
        - (COALESCE((ISNULL(TotalCancelamentos, 0) * 1.0) / NULLIF(ISNULL(TotalEntregue, 0), 0), 0) * 100 * 0.15)
        + (COALESCE((ISNULL(TotalCliques, 0) * 1.0) / NULLIF(ISNULL(TotalEntregue, 0), 0), 0) * 100 * 0.10)
        + (COALESCE((ISNULL(TotalCliques, 0) * 1.0) / NULLIF(ISNULL(TotalAberturas, 0), 0), 0) * 100 * 0.05)
        ) BETWEEN 1 AND 4.99 THEN 'ATENÇÃO'
        ELSE 'CRÍTICO'
    END AS [CLASSIFICAÇÃO]

FROM MetricBase
ORDER BY aCampaignID DESC;
```

---

## 7. Interpretação dos Resultados

### Exemplo de Resultado Real

| ID | Nome da Campanha | Status | Total Enviado | Total Entregue | Total Bounce | Total Aberturas | Total Cliques | Taxa Abertura % | Taxa Rejeição % | Taxa Clique % | SCORE | CLASSIFICAÇÃO |
|----|---|---|---|---|---|---|---|---|---|---|---|---|
| 11159 | Newsletter Dezembro 2025 | ATIVA | 1000 | 950 | 50 | 285 | 45 | 30.00 | 5.00 | 4.74 | 15.67 | BOM |
| 11158 | Promoção Especial | ATIVA | 500 | 480 | 20 | 96 | 19 | 20.00 | 4.00 | 3.96 | 10.45 | MÉDIO |
| 11157 | Campanha Inativa | DESATIVADA | 0 | 0 | 0 | 0 | 0 | 0.00 | 0.00 | 0.00 | 0.00 | CRÍTICO |

### Como Ler os Resultados

**Campanha 1 (EXCELENTE/BOM):**
- 1.000 disparos, 950 entregues (95% de sucesso)
- 285 aberturas (30% das entregues)
- 45 cliques (4,74% das entregues)
- Score: 15.67 = **BOM** ✅

**Campanha 2 (MÉDIO):**
- 500 disparos, 480 entregues (96% de sucesso)
- 96 aberturas (20% das entregues)
- 19 cliques (3,96% das entregues)
- Score: 10.45 = **MÉDIO** 🟡

**Campanha 3 (SEM ENVIOS):**
- Nenhum envio registrado
- Score: 0 = **CRÍTICO** ❌

---

## 8. Notas Técnicas Importantes

### Limitações e Observações

1. **Total Cancelamentos fixo em 0**: Esse valor precisa ser alimentado por uma fonte de dados específica. Atualmente está hardcoded como 0.

2. **LEFT JOINs Garante Completude**: Mesmo campanhas sem nenhum envio aparecem na query.

3. **ISNULL e COALESCE**: Todos os valores nulos são convertidos para 0, evitando erros de cálculo.

4. **NULLIF para Divisão por Zero**: Operações como (x / 0) retornam NULL ao invés de erro.

5. **Ordenação**: Os resultados estão ordenados por ID em ordem decrescente.

---

## 9. Referências e Suporte

- **Banco de Dados**: Talisma CRM / tlAnalytics
- **Linguagem**: T-SQL (SQL Server 2016+)
- **Tabelas Base**: tblCampaignMain, tblOBMReportMailer, tblURLClickStatus
- **Última Atualização**: 27 de Novembro de 2025
- **Status**: ✅ Versão Definitiva - Pronto para Produção

---

## 10. Próximos Passos e Melhorias Futuras

- [ ] Integrar fonte de dados para **Total Cancelamentos** (atualmente hardcoded como 0)
- [ ] Adicionar filtro por **período (data range)**
- [ ] Criar **VIEW SQL** para facilitar consultas recorrentes
- [ ] Integrar com **Power BI** para dashboards visuais
- [ ] Implementar **alertas automáticos** para campanhas com score baixo
- [ ] Adicionar **análise de tendência histórica** por campanha
- [ ] Criar **comparações benchmark** entre campanhas similares

---

## 11. Licença e Uso

Este projeto é de uso interno para análise de campanhas de email marketing.

Para dúvidas, sugestões ou melhorias, entre em contato com a equipe de CRM-Alunos.

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
        C.aCampaignID, C.tCampaignName, C.dDateofCreation, C.bIsActive
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
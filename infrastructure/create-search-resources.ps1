param(
    [string] $SearchServiceName,
    [string] $SearchServiceSku,
    [string] $SearchIndexName,
    [string] $SearchIndexerName,
    [string] $SearchDataSourceName,
    [string] $StorageAccountName,
    [string] $StorageContainerName,
    [string] $ResourceGroupName
)

# Get the search service admin API key
$searchService = Get-AzResource -ResourceType 'Microsoft.Search/searchServices' -ResourceName $SearchServiceName -ResourceGroupName $ResourceGroupName
$adminKey = (Invoke-AzRestMethod -Uri "https://management.azure.com$($searchService.ResourceId)/listAdminKeys?api-version=2021-04-01-preview" -Method Post).Content | ConvertFrom-Json | Select -ExpandProperty primaryKey

# Get storage account key
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName)[0].Value

# Create data source
$dataSourceDefinition = @{
    name = $SearchDataSourceName
    type = 'azureblob'
    credentials = @{
        connectionString = "DefaultEndpointsProtocol=https;AccountName=$StorageAccountName;AccountKey=$storageKey;EndpointSuffix=core.windows.net"
    }
    container = @{
        name = $StorageContainerName
    }
}
$dataSourcePayload = $dataSourceDefinition | ConvertTo-Json -Depth 10
$dataSourceHeaders = @{
    'api-key' = $adminKey
    'Content-Type' = 'application/json'
}
Invoke-RestMethod -Uri "https://$SearchServiceName.search.windows.net/datasources/$SearchDataSourceName`?api-version=2020-06-30" -Method Put -Headers $dataSourceHeaders -Body $dataSourcePayload

# Create index
$indexDefinition = @{
    name = $SearchIndexName
    fields = @(
        @{
            name = 'id'
            type = 'Edm.String'
            key = $true
            searchable = $false
        },
        @{
            name = 'metadata_storage_name'
            type = 'Edm.String'
            searchable = $true
            filterable = $true
            sortable = $true
            facetable = $true
        },
        @{
            name = 'metadata_storage_path'
            type = 'Edm.String'
            searchable = $false
            filterable = $true
            sortable = $true
        },
        @{
            name = 'metadata_content_type'
            type = 'Edm.String'
            searchable = $false
            filterable = $true
            sortable = $true
            facetable = $true
        },
        @{
            name = 'metadata_language'
            type = 'Edm.String'
            searchable = $false
            filterable = $true
            sortable = $true
            facetable = $true
        },
        @{
            name = 'metadata_author'
            type = 'Edm.String'
            searchable = $true
            filterable = $true
            sortable = $true
            facetable = $true
        },
        @{
            name = 'metadata_last_modified'
            type = 'Edm.DateTimeOffset'
            searchable = $false
            filterable = $true
            sortable = $true
            facetable = $false
        },
        @{
            name = 'metadata_creation_date'
            type = 'Edm.DateTimeOffset'
            searchable = $false
            filterable = $true
            sortable = $true
            facetable = $false
        },
        @{
            name = 'content'
            type = 'Edm.String'
            searchable = $true
            filterable = $false
            sortable = $false
            facetable = $false
            analyzer = 'standard.lucene'
        }
    )
}
$indexPayload = $indexDefinition | ConvertTo-Json -Depth 10
$indexHeaders = @{
    'api-key' = $adminKey
    'Content-Type' = 'application/json'
}
Invoke-RestMethod -Uri "https://$SearchServiceName.search.windows.net/indexes/$SearchIndexName`?api-version=2020-06-30" -Method Put -Headers $indexHeaders -Body $indexPayload

# Create indexer
$indexerDefinition = @{
    name = $SearchIndexerName
    dataSourceName = $SearchDataSourceName
    targetIndexName = $SearchIndexName
    schedule = @{
        interval = 'PT1H'
    }
    parameters = @{
        batchSize = 100
        maxFailedItems = 10
        maxFailedItemsPerBatch = 10
        configuration = @{
            parsingMode = 'default'
            indexedFileNameExtensions = '.pdf,.docx,.doc,.pptx,.ppt,.xlsx,.xls,.txt,.html,.htm,.csv,.json,.xml'
            excludedFileNameExtensions = '.png,.jpg,.jpeg,.gif,.mp3,.mp4,.avi'
        }
    }
    fieldMappings = @(
        @{
            sourceFieldName = 'metadata_storage_path'
            targetFieldName = 'metadata_storage_path'
            mappingFunction = @{
                name = 'base64Encode'
            }
        },
        @{
            sourceFieldName = 'metadata_storage_name'
            targetFieldName = 'metadata_storage_name'
        }
    )
    outputFieldMappings = @(
        @{
            sourceFieldName = 'content'
            targetFieldName = 'content'
        }
    )
}
$indexerPayload = $indexerDefinition | ConvertTo-Json -Depth 10
$indexerHeaders = @{
    'api-key' = $adminKey
    'Content-Type' = 'application/json'
}
Invoke-RestMethod -Uri "https://$SearchServiceName.search.windows.net/indexers/$SearchIndexerName`?api-version=2020-06-30" -Method Put -Headers $indexerHeaders -Body $indexerPayload

# Output the status information
$DeploymentScriptOutputs = @{}
$DeploymentScriptOutputs['searchServiceName'] = $SearchServiceName
$DeploymentScriptOutputs['searchIndexName'] = $SearchIndexName
$DeploymentScriptOutputs['searchIndexerName'] = $SearchIndexerName
$DeploymentScriptOutputs['searchDataSourceName'] = $SearchDataSourceName

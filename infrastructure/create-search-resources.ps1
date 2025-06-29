param(
    [Parameter(Mandatory=$true)]
    [string] $SearchServiceName,
    [Parameter(Mandatory=$true)]
    [string] $SearchServiceSku,
    [Parameter(Mandatory=$true)]
    [string] $SearchIndexName,
    [Parameter(Mandatory=$true)]
    [string] $SearchIndexerName,
    [Parameter(Mandatory=$true)]
    [string] $SearchDataSourceName,
    [Parameter(Mandatory=$true)]
    [string] $StorageAccountName,
    [Parameter(Mandatory=$true)]
    [string] $StorageContainerName,
    [Parameter(Mandatory=$true)]
    [string] $ResourceGroupName
)

# Set error action preference to stop on error
$ErrorActionPreference = "Stop"

try {
    # Get the search service admin API key
    Write-Host "Getting search service admin API key..."
    $searchService = Get-AzResource -ResourceType 'Microsoft.Search/searchServices' -ResourceName $SearchServiceName -ResourceGroupName $ResourceGroupName
    if (-not $searchService) {
        throw "Search service '$SearchServiceName' not found in resource group '$ResourceGroupName'."
    }
    
    $adminKeyResponse = Invoke-AzRestMethod -Uri "https://management.azure.com$($searchService.ResourceId)/listAdminKeys?api-version=2023-11-01" -Method Post
    $adminKey = ($adminKeyResponse.Content | ConvertFrom-Json).primaryKey
    
    if (-not $adminKey) {
        throw "Failed to retrieve admin key for search service '$SearchServiceName'."
    }

    # Get storage account key
    Write-Host "Getting storage account key..."
    $storageKeys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
    
    if (-not $storageKeys -or $storageKeys.Count -eq 0) {
        throw "Failed to retrieve keys for storage account '$StorageAccountName'."
    }
    
    $storageKey = $storageKeys[0].Value

    # Create data source
    Write-Host "Creating data source '$SearchDataSourceName'..."
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
    
    $dataSourceResponse = Invoke-RestMethod -Uri "https://$SearchServiceName.search.windows.net/datasources/$SearchDataSourceName`?api-version=2023-11-01" -Method Put -Headers $dataSourceHeaders -Body $dataSourcePayload
    Write-Host "Data source created successfully."

    # Create index
    Write-Host "Creating index '$SearchIndexName'..."
    $indexDefinition = @{
        name = $SearchIndexName
        fields = @(
            @{
                name = 'id'
                type = 'Edm.String'
                key = $true
                searchable = $false
                retrievable = $true
            },
            @{
                name = 'content'
                type = 'Edm.String'
                searchable = $true
                filterable = $false
                sortable = $false
                facetable = $false
                retrievable = $true
                analyzer = 'standard.lucene'
            },
            @{
                name = 'url'
                type = 'Edm.String'
                searchable = $false
                filterable = $true
                sortable = $true
                facetable = $false
                retrievable = $true
            },
            @{
                name = 'filepath'
                type = 'Edm.String'
                searchable = $false
                filterable = $true
                sortable = $true
                facetable = $false
                retrievable = $true
            },
            @{
                name = 'title'
                type = 'Edm.String'
                searchable = $true
                filterable = $true
                sortable = $true
                facetable = $true
                retrievable = $true
            },
            @{
                name = 'meta_json_string'
                type = 'Edm.String'
                searchable = $false
                filterable = $false
                sortable = $false
                facetable = $false
                retrievable = $true
            },
            @{
                name = 'contentVector'
                type = 'Collection(Edm.Single)'
                searchable = $true
                retrievable = $true
                dimensions = 1536
                vectorSearchConfiguration = 'my-vector-config'
            }
        ),
        vectorSearch = @{
            algorithmConfigurations = @(
                @{
                    name = 'my-vector-config'
                    kind = 'hnsw'
                    parameters = @{
                        m = 4
                        efConstruction = 400
                        efSearch = 500
                        metric = 'cosine'
                    }
                }
            )
        }
    }
    $indexPayload = $indexDefinition | ConvertTo-Json -Depth 10
    $indexHeaders = @{
        'api-key' = $adminKey
        'Content-Type' = 'application/json'
    }
    
    $indexResponse = Invoke-RestMethod -Uri "https://$SearchServiceName.search.windows.net/indexes/$SearchIndexName`?api-version=2023-11-01" -Method Put -Headers $indexHeaders -Body $indexPayload
    Write-Host "Index created successfully."

    # Create indexer
    Write-Host "Creating indexer '$SearchIndexerName'..."
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
                targetFieldName = 'filepath'
            },
            @{
                sourceFieldName = 'metadata_storage_name'
                targetFieldName = 'title'
            },
            @{
                sourceFieldName = 'metadata_storage_path'
                targetFieldName = 'id'
                mappingFunction = @{
                    name = 'base64Encode'
                }
            },
            @{
                sourceFieldName = 'metadata_storage_path'
                targetFieldName = 'url'
            }
        )
        outputFieldMappings = @(
            @{
                sourceFieldName = '/document/content'
                targetFieldName = 'content'
            }
        )
    }
    $indexerPayload = $indexerDefinition | ConvertTo-Json -Depth 10
    $indexerHeaders = @{
        'api-key' = $adminKey
        'Content-Type' = 'application/json'
    }
    
    $indexerResponse = Invoke-RestMethod -Uri "https://$SearchServiceName.search.windows.net/indexers/$SearchIndexerName`?api-version=2023-11-01" -Method Put -Headers $indexerHeaders -Body $indexerPayload
    Write-Host "Indexer created successfully."

    # Output the status information
    $DeploymentScriptOutputs = @{}
    $DeploymentScriptOutputs['searchServiceName'] = $SearchServiceName
    $DeploymentScriptOutputs['searchIndexName'] = $SearchIndexName
    $DeploymentScriptOutputs['searchIndexerName'] = $SearchIndexerName
    $DeploymentScriptOutputs['searchDataSourceName'] = $SearchDataSourceName
    
    Write-Host "Azure Search resources created successfully!"
}
catch {
    Write-Error "An error occurred: $_"
    throw
}

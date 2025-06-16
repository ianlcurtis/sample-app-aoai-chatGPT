# Deploying with Bicep

This document provides detailed instructions on deploying the Sample Chat App with AOAI using Bicep templates.

## Prerequisites

- An Azure subscription
- Azure CLI installed (version 2.48.1 or later)
- Git for cloning the repository

## Deployment Steps

### 1. Fork or Clone the Repository

Fork or clone this repository to your own GitHub account if you want to customize the deployment.

### 2. Compile the Bicep File (if making changes)

If you've made changes to the Bicep files, you'll need to compile them to JSON:

```bash
az bicep build --file infra/main.bicep --outfile infra/main.json
```

### 3. Push Changes to Your Repository

If you've made changes, push them to your repository:

```bash
git add infra/main.json
git commit -m "Update compiled Bicep template"
git push
```

### 4. Deploy Using the "Deploy to Azure" Button

- Go to the README.md file
- Click on the "Deploy to Azure" button under the "Deploy using Bicep" section
- This will open the Azure portal with the template deployment page

### 5. Configure Deployment Parameters

When deploying through the Azure portal, you'll need to provide values for these key parameters:

- **Subscription**: Your Azure subscription
- **Resource Group**: Create new or use existing
- **Region**: Azure region for deployment
- **Environment Name**: Name for your environment (used to generate unique resource names)
- **Location**: Primary location for all resources
- **Principal ID**: (Optional) ID of the user or app to assign application roles
- **Azure OpenAI Settings**:
  - OpenAI Resource Name (optional if using existing)
  - OpenAI Resource Group Name (optional if using existing)
  - OpenAI SKU Name (if creating new)
- **Azure Search Settings**:
  - Search Service Name (optional if using existing)
  - Search Service Resource Group Name (optional if using existing)
  - Search Service SKU Name (if creating new)
- **Authentication Settings**:
  - Auth Client ID
  - Auth Client Secret

### 6. Review and Create

- Review your settings
- Click "Create" to deploy the resources

### 7. Post-Deployment Configuration

After deployment completes:

1. Navigate to the deployed App Service in the Azure portal
2. Configure the application settings as described in the main README.md file
3. Restart the App Service if needed

## Customizing the Deployment

If you need to customize the deployment:

1. Modify the Bicep files in the `/infra` folder
2. Compile the updated Bicep files to JSON
3. Push the changes to your repository
4. Update the "Deploy to Azure" button URL in the README.md to point to your repository

## Understanding the Resources Deployed

The Bicep template deploys:

- App Service and App Service Plan for hosting the web application
- Azure OpenAI resources (if not using existing ones)
- Azure Cognitive Search for search functionality
- Azure Cosmos DB for chat history
- Form Recognizer services for document processing
- All necessary security configurations and permissions

## Troubleshooting

If you encounter issues during deployment:

- Check the deployment logs in the Azure portal
- Ensure all required parameters are provided
- Verify your Azure subscription has sufficient permissions and quota for the resources
- Check if any resources with the same names already exist

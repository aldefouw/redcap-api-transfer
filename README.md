# REDCap API Transfer Tool

This project is aimed at people who want to transfer a REDCap project from REDCap Server A to REDCap Server B.

This project contains libraries encapsulated by a Docker image that aim to make transferring a REDCap project from one server to another as simple as running a single script from command line.

Instructions in this document are written for a Unix-style environment, but the scripts will likely work in a Windows environment as well (with some appropriate modifications).

The scripts work by directly connecting to the **source REDCap's API** and pushing that data into the **destination REDCap** via API.

**Please note that this library will transfer both REDCap data and files.**

## Technical Prerequisites

- Docker must be installed on the machine the script is run on.  

Installation instructions vary based upon the OS being run:
   - [Install Docker on Windows](https://docs.docker.com/docker-for-windows/install/)
   - [Install Docker on a Mac](https://docs.docker.com/docker-for-mac/install/)
   - Install Docker on Linux
      - [CentOS](https://docs.docker.com/engine/install/centos/)
      - [Debian](https://docs.docker.com/engine/install/debian/)
      - [Fedora](https://docs.docker.com/engine/install/fedora/)
      - [Ubuntu](https://docs.docker.com/engine/install/ubuntu/)

- Machine the script is run on MUST be able to communicate with REDCap Server A and REDCap Server B

## Disclaimer

**Use the library at your own risk.**  

**No warranty against the loss / corruption of data as a result of running a script against the provided library.**

**Testing in development environment prior to running against production is highly recommended.**

## Prerequisites

There are some things that you will need in both environments in order for this script to work.

* 1\. Exact structural match of **Source REDCap project** on **Destination REDCap server**
    * Structural components for project are downloadable / uploadable on recent versions of REDCap
    * For standard projects:
        * Identical  **Data Dictionary** on both servers
    * For longitudinal projects:
        * Identical  **Data Dictionary** on both servers
        * Identical **Arms / Events** on both servers
        * Identical **Instrument Designations** on both servers
    

* 2\. **API tokens** for project
  * Configured on **Source REDCap** server
  * Configured on **Destination REDCap** server 
        

## Configuration

After cloning this repository to your machine, create a **config.yml** file in the **/config/** folder of this project.

In **config.yml**, enter the following:

    settings:
      processes: 8
      verbose: false
    
    projects:
      project_name_here:
        source:
          url: https://redcap.source.url/api/
          token: SOURCE_TOKEN_HERE
    
        destination:
          url: https://redcap.destination.url/api/
          token: DESTINATION_TOKEN_HERE

        transfer_new_records_only: true
        processes: 1 # Takes precedence over the processes listed in settings
        verbose: false  # Takes precedence over the verbose flag listed in settings
      
Replace above values with appropriate values for your REDCap URLs and tokens.          
    
**_Note that YAML format is white-space sensitive._**  

You will need proper indentations for the scripts to work.  

      
# Getting Started

# Install Docker

Although it's outside the scope of this README, this library is dependent upon you having Docker available and installed on the machine you are executing the script from.

To install Docker on your machine, please reference the following guide at Docker's website:

https://docs.docker.com/get-docker/

## Run the Deployment Scripts to Check for Newest Version

    $ sh deploy.sh
    
If you run the deploy script, it will automatically select the newest version of this script from the repository.  From there, an updated version of the build is generated using docker-compose functionality.  

    
## Transfer Single Record

Check to see if your APIs are configured correctly by testing against one record before attempting an entire project.

On your machine, you can test your source and destination end points by running the following:

    $ sh transfer_single_record.sh your_project_name_here 1
    
## Transfer Entire Project
        
Once you have verified that a single record can appropriately transfer, you can try transferring the entire project.

To transfer entire project, issue the following command:

    $ sh transfer_all_records.sh your_project_name_here

## Only Transfer New Records

If you only want to transfer __new__ records to the destination there is an option to do so.  (This is useful for syncing two REDCap instances.)

By default this option is set to false.  If you wish to enable it, set the following at the project level of config.yml:
   
    projects:
      project_name_here:
        ..
        transfer_new_records_only: true

## Run parallel processes

The library uses [Parallel](https://github.com/grosser/parallel) gem to manage parallel processing of the data.  

Increasing the number of simultaneous processes can immensely speed up the export / import process.

To adjust the number of simlutaneous processes, simply change the value on "processes" attribute in config.yml.

For instance, if you wanted 6 processes instead of 8, you'd enter the following to apply this as the default:

    settings:
      processes: 6

On a per project basis, you'd do the following:

    your_project_name_here:
        source:
          url: https://redcap.source.url/api/
          token: SOURCE_TOKEN_HERE
    
        destination:
          url: https://redcap.destination.url/api/
          token: DESTINATION_TOKEN_HERE

    processes: 6

Please note that the per-project setting supercedes what is set as the default in settings.

## Troubleshooting

If you encounter problems with your data transfer, logs can be very useful to troubleshoot issues.  

**Error messages** are written to the following location:

     ##your_repository_location##/logs/errors.log
     
**Requests with Response Code 200** are written to the following location:

     ##your_repository_location##/logs/info.log
     
There are some instances (particularly with file uploads) where REDCap returns an error but returns **Response Code 200**.  

In these cases, I try to catch the Error and write to **errors.log** as well.  

But there may be instances that are not properly caught.  So if you're not seeing the data you're expecting, give **info.log** a look.

#### Longitudinal Studies

For a longitudinal study, if you receive errors that indicate data cannot be written to a particular instrument, you may need to fix data on the **Source REDCap** before you can import data correctly on **Destination REDCap**.

**Example Error:**

      {"error":""record”,”field_name”,”1”,”This field (‘field_name’) exists on an instrument that is not designated for the event named ‘Event (Arm Number)'. You are not allowed to import data for this field into this event."}

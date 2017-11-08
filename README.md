# redcap-api-transfer

This project contains Ruby libraries that aim to make transferring a REDCap project from one server to another as simple as running a single script from command line.

Instructions in this document are written for a Unix-style environment, but the scripts will likely work in a Windows environment as well (with some appropriate modifications).

The scripts work by directly connecting to the **source REDCap's API** and pushing that data into the **destination REDCap** via API.

**Please note that this library will transfer both REDCap data and files.**

## Disclaimer

**Use the library at your own risk.**  

**No warranty against the loss / corruption of data as a result of running a script against the provided library.**

**Testing in development environment prior to running against production is highly recommended.**

## Pre-requisites

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

    source:
      url: https://redcap.source.url/api/
      token: api_token_string
    
    destination:
      url: https://redcap.destination.url/api/
      token: api_token_string 
      
Replace above values with appropriate values for your REDCap URLs and tokens.          
    
**_Note that YAML format is white-space sensitive._**  

You will need proper indentations for the scripts to work.  

## Export Data from Source

Download a **Full Data Export** of the project's data from the **Source REDCap**.

Rename the **Full Data Export** to the following:
     
    data.csv

Then, put the file in the following folder of your local repository:

    /export_data/
    
Thus, your **Full Data Export** will exist here:

    ##your_repository_location##/export_data/data.csv
    
## Installing RVM & Ruby 

If you already have an RVM and Ruby environment established, you can safely skip this step.  However, I still recommend that you create a Gemset to manage your gem dependencies.

RVM is a command-line tool that allows you to easily manage several versions of Ruby and Gemsets.

### Install RVM

To install RVM, run the following:
    
    gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
    
    curl -sSL https://get.rvm.io | bash -s stable

### Install Ruby

To install a Ruby version into RVM, run a command like the following:

    rvm install 2.3.8

Substitute 2.3.8 for the version you wish to install.  

### Use Ruby

To use a version of Ruby, run the following:

    rvm use 2.3.8
    
Again, substitute 2.3.8 for your Ruby version.    

### Create a Gemset

To create a gemset, run the following:

    rvm gemset create gemset_name

### Use a Gemset

To use a gemset, run the following:

    rvm gemset use gemset_name


## Loading Required Libraries

If you have RVM installed (or a Ruby environment you are satisfied with), loading the libraries is easy.  Gems (libraries) and their dependencies are managed by the Gemfile.  

First install bundler:

      gem install bundler
      
Then run the following to install the libraries themselves:  
      
      bundle install      
      
# Getting Started

    
## Transfer Single Record

Check to see if your APIs are configured correctly by testing against one record before attempting an entire project.

Use the template provided in single_record.rb.example.

Set your appropriate record ID in your file called **single_record.rb**: 

    require "#{Dir.getwd}/library/transfer_records"
    
    @transfer = TransferRecords.new(processes: 1)
    @transfer.transfer_record_to_destination("record_id_here")
    
To run the file, at the command prompt, type the following and hit enter:

    ruby single_record.rb
    
    
## Transfer Entire Project
        
Once you have verified that a single record can appropriately transfer, you can try transferring the entire project.

Use the template provided in all_records.rb.example.

To transfer entire project, use code like the following in a file called **transfer_records.rb**: 

    require "#{Dir.getwd}/library/transfer_records"
    
    @transfer = TransferRecords.new(processes: 8)
    @transfer.run   
    
To run the file, at the command prompt, type the following and hit enter:

    ruby all_records.rb


## Run parallel processes

The library uses [Parallel](https://github.com/grosser/parallel) gem to manage parallel processing of the data.  

Increasing the number of simultaneous processes can immenensely speed up the export / import process.

To adjust the number of simlutaneous processes, simply change the value on "processes" attribute.

For instance, if you wanted 6 processes instead of 8:

    @transfer = TransferRecords.new(processes: 6)

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

## Introduction

This chapter introduces the problem of working with data that is larger than memory.
R is not naturally suited to working on data that doesn't fit into memory, but the **arrow** R package offers an intuitive interface to work with bigger data with ease.
The chapter then provides some background on the arrow package and the broader Apache Arrow project, which intends to make it fast and efficient for analytic systems to operate and share data.

## Getting Started

This chapter introduces the arrow package and key concepts from it.
It shows how to open an Arrow Dataset, a collection of many files, and how to gain insights from it as if it were a single table.
It introduces the Parquet file format, a binary file format optimized for storing analytics data with broad adoption across the industry.
And it does this through exploring the Public Use Microdata Sample (PUMS) dataset from the United States Census, which is the dataset used throughout the book.

## Data Manipulation

This chapter dives in to using **tidyverse** functions to work with Arrow Datasets.
It gives examples of some of the hundreds of functions you can use in **dplyr** pipelines to modify and aggregate data, including string and datetime operations.
It demonstrates common data cleaning tasks, and shows how to do more complex operations like joining datasets together.
Finally, it goes deeper to explain how the arrow package translates your R code into efficient query plans that are evaluated lazily without pulling all the data into memory.

## Files and Formats

This chapter explores the different file formats that Arrow can read and write, including CSV, JSON, Arrow, and Parquet.
It focuses particularly on the tools you need to ingest data from CSVs and store them in Parquet files with high fidelity, and highlights many of the benefits of using Parquet files.
Parquet files are generally fast to read, use various forms of encodings and compression to reduce file size, are widely supported in the analytics ecosystem, and can faithfully preserve the data types and structure of the original data.
The chapter concludes with an example workflow for converting CSV files to Parquet, including data transformations in the middle.

## Datasets

This chapter goes deeper into Arrow Datasets.
It shows how to read datasets in various file formats, as well as the range of options for selecting files and combining different formats.
It then discusses partitioning, the division of a dataset into smaller pieces, how it affects performance, and how to choose your partitioning strategy to best meet your needs.
Along the way, it also shows how to write datasets back to disk, controlling how partitions are created, among other options.

## Cloud

This chapter shows how to use arrow to work with datasets in cloud storage.
The arrow package include support for Amazon Simple Storage Service (S3) and Google Cloud Storage (GCS), and you can apply the same practices shown in the previous chapters to data stored there.
There are some differences in how you access data in the cloud, and the chapter walks through how to get best results.
It shows how to provide authentication and other configuration to the cloud services.
It analyses the cost, in terms of slower access time, of accessing data over the network and identifies strategies to minimize it.
It also shows how the efficiency of arrow's querying helps reduce the amount of data you need to transfer.

## Advanced Topics

This chapter covers more advanced topics in working with Arrow Datasets.
It shows how to create user-defined functions (UDFs) in R and use them in arrow queries.
It demonstrates how to construct queries that flow from arrow to **duckdb** and back, taking advantage of the strengths of each package and highlighting the value of the Arrow format for interoperability.
Finally, it introduces extension types, a way to represent data in Arrow that doesn't fit into the standard types, and shows how geospatial methods make use of them.

## Sharing Data and Interoperability

One of the benefits of Arrow as a standard is that data can be easily shared between different applications or libraries that understand the format.
This chapter shows examples where Arrow is used as the means of exchanging data, and how that results in major speedups.
Arrow memory can be passed between libraries in the same process, and this can used to speed up data transfer between R and Python through the **reticulate** package.
The chapter also explains how this mechanism powers the integration with **duckdb**, discussed in the previous chapter.
It then discusses how Arrow is used to speed up interactions with Apache Spark, and that it does this all behind the scenes, without the user needing to change their code.
Finally, it discusses the **nanoarrow** package for lightweight integrations with other Arrow-native projects, and looks ahead to future developments in Arrow and the broader ecosystem.

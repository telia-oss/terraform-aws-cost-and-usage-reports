# pylint: disable=import-error, too-many-locals, superfluous-parens
"""Lambda function for converting a cost-and-usage report csv file to parquet."""
import time
import boto3
import botocore
import pandas as pd
import pyarrow.parquet as pq
import pyarrow as pa
import s3fs


def lambda_handler(event, _):
    """Lambda entry point"""
    source_path = 's3://' + event['bucket'] + '/' + event['source_key']
    target_path = 's3://' + event['bucket'] + '/' + event['target_key']

    print('Source: ' + source_path)
    print('Target: ' + target_path)

    s3_client = boto3.client('s3')
    found = False
    # Ensure file exists before we actually run the conversion
    while not found:
        try:
            s3_client.head_object(Bucket=event['bucket'], Key=event['source_key'])
        except botocore.exceptions.ClientError:
            print('Waiting for: "' + source_path + '" to exist')
            time.sleep(10)
        else:
            print('Found: "' + source_path + '"')
            found = True

    s3fs_source = s3fs.S3FileSystem()
    s3fs_target = s3fs.S3FileSystem()

    with s3fs_source.open(source_path, 'rb') as source_file, \
            s3fs_target.open(target_path, 'wb') as target_file:
        # Open a stream reader for the csv file
        csv_stream = pd.read_csv(
            source_file, skiprows=0,
            compression='gzip',
            dtype=object,
            iterator=True,
            chunksize=100000
        )

        parquet_writer = None
        for i, chunk in enumerate(csv_stream):
            print('Reading chunk: ' + str(i))

            # First chunck, get schema and setup writer
            if not parquet_writer:
                # Fetch columns from header, hardcodes type to string
                columns = [pa.field(column, pa.string()) for column in chunk.columns]

                # Generate schema from columns
                parquet_schema = pa.schema(columns)

                # Open a writer to S3
                parquet_writer = pq.ParquetWriter(target_file, parquet_schema, compression='snappy')

            # Read the first chunk
            table = pa.Table.from_pandas(chunk, preserve_index=False)

            print('Writing chunk: ' + str(i))
            parquet_writer.write_table(table)

        parquet_writer.close()
        print('Done processing "' + source_path + '"')

    return event['target_key']

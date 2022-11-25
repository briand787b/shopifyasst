#!/usr/bin/env python3

import argparse
import shopify
import os.path

def main():
    parser = argparse.ArgumentParser(
        prog = 'Uploader',
        description = 'Creates Shopify product'
    )

    parser.add_argument('tags', type=str, nargs='+',
        help='tags from image EXIF data')
    parser.add_argument('--filename', dest='filename',
        help='name of image file to create from')
    parser.add_argument('--token', dest='token',
        help='shopify private app password')
    parser.add_argument('--url', dest='url',
        help='shopify store url')

    args = parser.parse_args()
    # print(f'tags from cli args: {args.tags}')
    # print(f'filename from cli args: {args.filename}')

    parsedTags = parseTags(args.tags)
    # print(f'parsed tags: {parsedTags}')

    createShopifyProduct(
        args.filename,
        args.token,
        args.url,
        parsedTags,
    )

def parseTags(tagArr):
    attrs = []
    tmp_attrs = []
    for elem in tagArr:
        tmp_attrs.append(elem)
        if elem[-1] == ',':
            full_tag = " ".join(tmp_attrs)
            tmp_attrs[-1][:-1]
            attrs.append(full_tag[:-1])
            tmp_attrs = []

    attrs.append(" ".join(tmp_attrs))
    return attrs

def createShopifyProduct(filename, token, url, tags):
    api_version = '2021-10'

    session = shopify.Session(url, api_version, token)
    shopify.ShopifyResource.activate_session(session)
    # ...

    title = os.path.splitext(os.path.basename(filename))[0]
    
    product = shopify.Product()
    product.title = title
    product.id                          # => 292082188312
    product.attributes['tags'] = tags
    # print(f'product before save: {product.attributes}')
    product.save()                      # => True
    # print(f'product after save: {product.attributes}')

    shopify.ShopifyResource.clear_session()
    print(f'{product.id}')

if __name__ == '__main__':
    main()
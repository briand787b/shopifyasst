#!/usr/bin/env python3

import argparse
import shopify
import os.path

# constants
api_version = '2021-10'

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

    product_id = createShopifyProduct(
        args.filename,
        args.token,
        args.url,
        parsedTags,
    )

    createShopifyProductImage(
        args.filename,
        product_id,
        args.token,
        args.url,
    )

    print(product_id)

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

def image_title(filename):
    return os.path.splitext(os.path.basename(filename))[0]

def createShopifyProduct(filename, token, url, tags):
    session = shopify.Session(url, api_version, token)
    shopify.ShopifyResource.activate_session(session)
    
    product = shopify.Product()
    product.title = image_title(filename)
    product.attributes['tags'] = tags
    product.save()

    shopify.ShopifyResource.clear_session()
    # print(f'{product.id}')
    return product.id

def createShopifyProductImage(filename, product_id, token, url):
    with open(filename, 'rb') as f:
        contents = f.read()

    session = shopify.Session(url, api_version, token)
    shopify.ShopifyResource.activate_session(session)

    img = shopify.Image()
    img.product_id = product_id
    img.attach_image(contents, image_title(filename))
    img.save()

    shopify.ShopifyResource.clear_session()

if __name__ == '__main__':
    main()
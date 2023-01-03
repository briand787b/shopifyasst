import argparse
import shopify
import os.path

# constants
api_version = '2021-10'


def main():
    parser = argparse.ArgumentParser(
        prog='Uploader',
        description='Creates Shopify product'
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
    parsedTags = parseTags(args.tags)

    product_id = createShopifyProduct(
        args.filename,
        args.token,
        args.url,
        parsedTags,
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


def shopifyProductImage(filename):
    with open(filename, 'rb') as f:
        contents = f.read()

    img = shopify.Image()
    img.attach_image(contents, image_title(filename))
    return img


def createShopifyProduct(filename, token, url, tags):
    session = shopify.Session(url, api_version, token)
    shopify.ShopifyResource.activate_session(session)

    product = shopify.Product({
        "title": image_title(filename),
        "product_type": 'Image',
        "tags": tags,
        "variants": [
            shopify.Variant({
                "title": "Unlimited Downloads",
                "price": "20.00",
                "taxable": True,
                "inventory_policy": "continue",
                "requires_shipping": False
            }),
        ],
        "images": [
            shopifyProductImage(filename),
        ]
    })
    product.save()

    shopify.ShopifyResource.clear_session()
    return product.id


if __name__ == '__main__':
    main()

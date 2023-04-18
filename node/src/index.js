const fs = require("fs");
const FormData = require("form-data");
const axios = require("axios");

const price = '65.00';

const filename = process.env.FILENAME;
const tags = process.env.TAGS;
const shopifyAPIKey = process.env.SHOPIFY_TOKEN;
const shopifyProductIDOutputFile = process.env.SHOPIFY_PRODUCT_ID_OUT_PATH

// APP SCRIPT
async function app() {
    const shopifyVideoSourceUrl = await uploadVideoToShopify(filename);

    console.log(`Creating shopify product for ${filename}`);
    const shopifyResponse = await createShopifyProduct(shopifyVideoSourceUrl);

    // Clean Up all integration work (delete input/output s3, delete local videos )
    console.log("Watermarking Script Ended!!!");

    fs.writeFileSync(shopifyProductIDOutputFile, shopifyResponse.id);
}

async function uploadVideoToShopify(filename) {
    let stagedTarget;
    // Stage Video first to get upload url
    const body = {
        query: `
            mutation stagedUploadsCreate($input: [StagedUploadInput!]!) {
                stagedUploadsCreate(input: $input) {
                stagedTargets {
                    url,
                    resourceUrl,
                    parameters {
                        name,
                        value
                    }
                }
                userErrors {
                    field
                    message
                }
                }
            }
        `,
        variables: {
            input: [
                {
                    fileSize: `${fs.statSync(filename).size}`,
                    filename: filename,
                    httpMethod: "POST",
                    mimeType: "video/mp4", // WARNING: this is hardcoded
                    resource: "VIDEO",
                },
            ],
        },
    };

    try {
        const productResponse = await axios({
            method: "post",
            url: "https://citystock2.myshopify.com/admin/api/2023-01/graphql.json",
            headers: {
                "X-Shopify-Access-Token": shopifyAPIKey,
                "Content-Type": "application/json",
            },
            data: body,
        });

        stagedTarget =
            productResponse.data.data.stagedUploadsCreate.stagedTargets[0];
    } catch (err) {
        console.log(err);
        throw Error("Failed to create video shopify staged target");
    }

    // Upload video to staged url
    const formData = new FormData();

    console.log('staged target:  ')
    console.log(stagedTarget)
    console.log('writing form...');
    formData.append(
        "signature",
        stagedTarget.parameters.find((p) => p.name === "signature").value
    );
    formData.append(
        "policy",
        stagedTarget.parameters.find((p) => p.name === "policy").value
    );
    formData.append(
        "GoogleAccessId",
        stagedTarget.parameters.find((p) => p.name === "GoogleAccessId").value
    );
    formData.append(
        "key",
        stagedTarget.parameters.find((p) => p.name === "key").value
    );
    console.log('about to finish form')

    // contents = fs.readFileSync(filename)
    // contents = fs.openSync(filename, 'r')
    // console.log(`content size: ${contents.length}`);
    // const blob = new Blob([contents], {type: "video/mp4"});

    // FILE NEEDS TO BE THE LAST THING APPENEDED
    console.log('about to add big file')
    formData.append("file", fs.createReadStream(filename));

    try {
        await axios.post(
            "https://shopify-video-production-core-originals.storage.googleapis.com",
            formData,
            {
                headers: formData.getHeaders(),
            }
        );
    } catch (err) {
        console.log(err.response.data);
        throw Error("failed to upload video to shopify");
    }

    return stagedTarget.resourceUrl;
}

async function createShopifyProduct(shopifyVideoSourceUrl) {
    const body = {
        query: `
      mutation productCreate($input: ProductInput!, $media: [CreateMediaInput!]) {
        productCreate(input: $input, media: $media) {
          product {
            id
          }
        
          userErrors {
            field
            message
          }
        }
      }
    `,
        variables: {
            input: {
                title: filename,
                productType: "Video",
                status: "ACTIVE",
                vendor: "City Stock",
                tags: tags.split(","),
                variants: [
                    {
                        title: "Default Title",
                        price: price,
                        requiresShipping: false,
                    },
                ],
            },
            media: [
                {
                    alt: filename,
                    mediaContentType: "VIDEO",
                    // s3 url of the watermarked video from shotstack output
                    originalSource: shopifyVideoSourceUrl,
                },
            ],
        },
    };

    try {
        const productResponse = await axios({
            method: "post",
            url: "https://citystock2.myshopify.com/admin/api/2023-01/graphql.json",
            headers: {
                "X-Shopify-Access-Token": shopifyAPIKey,
                "Content-Type": "application/json",
            },
            data: body,
        });

        console.log(productResponse.data.data.productCreate.product);
        return productResponse.data.data.productCreate.product;
    } catch (err) {
        console.log(err.response.data.errors);
        throw Error("could not create shopify product")
    }
}

// Launch App
app();

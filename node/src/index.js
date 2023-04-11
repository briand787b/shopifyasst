const fs = require("fs");
const FormData = require("form-data");
const axios = require("axios");
const array = require("lodash/array");
const string = require("lodash/string");
const path = require("path");
const { execSync } = require("child_process");
const { getVideoDurationInSeconds } = require("get-video-duration");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const {
  ListObjectsV2Command,
  S3Client,
  GetObjectCommand,
} = require("@aws-sdk/client-s3");

const shotstackUrl = process.env.SHOTSTACK_BASE_URL;
const shotstackApiKey = process.env.SHOTSTACK_API_KEY;
const bucketName = process.env.AWS_BUCKET_NAME;
const awsRegion = process.env.AWS_REGION;
const awsOutputFolderKey = process.env.AWS_OUTPUT_FOLDER_KEY;
const awsWatermarkFileKey = process.env.AWS_WATERMARK_FILE_KEY;
const awsSourceFileKey = decodeURIComponent(process.env.AWS_SOURCE_FILE_KEY);
const filename = decodeURIComponent(process.env.FILENAME);
const tags = process.env.TAGS;
const price = process.env.PRICE;
const outputFileKey = `${process.env.AWS_OUTPUT_FOLDER_KEY}/WATERMARKED ${filename}.mp4`;

const s3Client = new S3Client({
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
  region: awsRegion,
});

// APP SCRIPT
async function app() {
  const signedWatermarkImage = await getPresignedWatermarkImage();

  const sourceVideocommand = new GetObjectCommand({
    Bucket: bucketName,
    Key: awsSourceFileKey,
  });

  const signedUnmarkedVideoUrl = await getSignedUrl(
    s3Client,
    sourceVideocommand,
    {
      expiresIn: 3600,
    }
  );

  const videoDuration = await getVideoDurationInSeconds(signedUnmarkedVideoUrl);

  // Create watermarking with ShotStack
  const shotstackResponse = await renderVideo({
    filename,
    videoDuration,
    signedWatermarkImage,
    signedUnmarkedVideoUrl,
  });

  let checkStatus = () =>
    axios({
      method: "get",
      url: shotstackUrl + "render/" + shotstackResponse.response.id,
      headers: {
        "x-api-key": shotstackApiKey,
        "content-type": "application/json",
      },
    });

  let validateProgress = (result) =>
    !(
      result.data.response.status === "done" ||
      result.data.response.status === "failed"
    );

  const renderStatus = await poll(checkStatus, validateProgress, 3000);

  if (renderStatus === "failed") {
    console.log(`Failed to watermark file ${filename}`);
    throw Error(`Failed to watermark file ${filename}`);
  }

  // Delay 10 seconds before downloading watermarked videos to local dive
  console.log("Started 5 second buffer for shot stack to finish jobs");
  execSync("sleep 5");

  // Get S3 Watermarked Video File
  const watermarkedVideoSource = new GetObjectCommand({
    Bucket: bucketName,
    Key: outputFileKey,
  });

  const watermarkedVideoData = await s3Client.send(watermarkedVideoSource);

  const shopifyVideoSourceUrl = await uploadVideoToShopify(
    watermarkedVideoData
  );

  console.log(`Creating shopify product for ${filename}`);
  const shopifyResponse = await createShopifyProduct(shopifyVideoSourceUrl);

  // Clean Up all integration work (delete input/output s3, delete local videos )
  console.log("Watermarking Script Ended!!!");

  fs.writeFileSync(process.env.SHOPIFY_PRODUCT_ID_OUT_PATH, shopifyResponse.id);
}

async function getPresignedWatermarkImage() {
  const command = new GetObjectCommand({
    Bucket: bucketName,
    Key: awsWatermarkFileKey,
  });

  try {
    const url = await getSignedUrl(s3Client, command, { expiresIn: 3600 });

    return url;
  } catch (error) {
    console.log(error);
  }
}

async function renderVideo({
  signedWatermarkImage,
  signedUnmarkedVideoUrl,
  filename,
  videoDuration,
}) {
  const payload = {
    timeline: {
      background: "#000000",
      tracks: [
        {
          clips: [
            {
              asset: {
                type: "image",
                src: signedWatermarkImage,
              },
              start: 0,
              length: videoDuration,
              fit: "none",
              scale: 0.33,
              opacity: 0.5,
              position: "center",
            },
          ],
        },
        {
          clips: [
            {
              asset: {
                type: "video",
                src: signedUnmarkedVideoUrl,
              },
              start: 0,
              length: videoDuration,
            },
          ],
        },
      ],
    },
    output: {
      format: "mp4",
      resolution: "sd",
      destinations: [
        {
          provider: "s3",
          options: {
            region: awsRegion,
            bucket: `${bucketName}/${awsOutputFolderKey}`,
            filename: `WATERMARKED ${filename}`,
          },
        },
        {
          provider: "shotstack",
          exclude: true,
        },
      ],
    },
  };

  console.log(`Started watermarking video ${filename}`);

  const response = await axios({
    method: "post",
    url: shotstackUrl + "render",
    headers: {
      "x-api-key": shotstackApiKey,
      "content-type": "application/json",
    },
    data: JSON.stringify(payload),
  });

  return response.data;
}

async function poll(fn, fnCondition, ms) {
  let result = await fn();

  while (fnCondition(result)) {
    console.log("Generating Watermark...");
    await wait(ms);
    result = await fn();
  }

  return result.data.response.status;
}

function wait(ms = 1000) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

async function uploadVideoToShopify(watermarkedVideoData) {
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
          fileSize: `${watermarkedVideoData.ContentLength}`,
          filename: `WATERMARKED ${filename}.mp4`,
          httpMethod: "POST",
          mimeType: watermarkedVideoData.ContentType,
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
        "X-Shopify-Access-Token": "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",
        "Content-Type": "application/json",
      },
      data: body,
    });

    stagedTarget =
      productResponse.data.data.stagedUploadsCreate.stagedTargets[0];
  } catch (err) {
    console.log(err.response.errors);
    throw Error("Failed to create video shopify staged target");
  }

  // Upload video to staged url
  const formData = new FormData();

  console.log(`WATERMARKED ${filename}.mp4`);
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

  // FILE NEEDS TO BE THE LAST THING APPENEDED
  formData.append("file", watermarkedVideoData.Body);

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
        title: `${string.capitalize(filename)}`,
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
        "X-Shopify-Access-Token": "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",
        "Content-Type": "application/json",
      },
      data: body,
    });

    console.log(productResponse.data.data.productCreate.product);
    return productResponse.data.data.productCreate.product;
  } catch (err) {
    console.log(err.response.data.errors);
  }
}

// Launch App
app();

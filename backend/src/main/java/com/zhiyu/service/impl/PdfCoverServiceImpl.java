package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.zhiyu.entity.Textbook;
import com.zhiyu.mapper.TextbookMapper;
import com.zhiyu.service.PdfCoverService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.pdfbox.Loader;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.rendering.ImageType;
import org.apache.pdfbox.rendering.PDFRenderer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageOutputStream;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * 教材封面生成服务实现
 *
 * 用 PDFBox 把 PDF 第一页渲染成 JPG 缩略图，存到 uploads/covers/ 下，
 * 返回 /uploads/covers/xxx.jpg 这样的可访问 URL（该路径已配置为免鉴权静态资源）。
 *
 * 设计原则：封面只是锦上添花，**任何失败都不能阻断主流程**——
 * PDF 加密/损坏/非 PDF/渲染异常一律返回 empty，由调用方决定是否降级。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PdfCoverServiceImpl implements PdfCoverService {

    private final TextbookMapper textbookMapper;

    /** 渲染 DPI：72 足以覆盖移动端 64px 封面（×3 屏 ≈ 192px），再高只是浪费体积 */
    private static final float RENDER_DPI = 72f;

    /** JPG 压缩质量：0.82 在清晰度和体积之间平衡，单张封面约 40~90KB */
    private static final float JPEG_QUALITY = 0.82f;

    @Value("${zhiyu.upload.dir:./uploads}")
    private String uploadDir;

    @Value("${zhiyu.upload.base-url:/uploads}")
    private String uploadBaseUrl;

    @Override
    public Optional<String> generateCover(File pdfFile) {
        if (pdfFile == null || !pdfFile.exists() || !pdfFile.isFile()) {
            log.debug("[cover] 跳过：文件不存在 {}", pdfFile);
            return Optional.empty();
        }
        // 只对 PDF 生成封面；epub/txt/doc 等格式无法渲染
        if (!pdfFile.getName().toLowerCase().endsWith(".pdf")) {
            log.debug("[cover] 跳过：非 PDF 文件 {}", pdfFile.getName());
            return Optional.empty();
        }

        Path coversDir = Paths.get(uploadDir, "covers");
        String filename = "cover_" + UUID.randomUUID() + ".jpg";
        Path target = coversDir.resolve(filename);

        try {
            Files.createDirectories(coversDir);
            BufferedImage image = renderFirstPage(pdfFile);
            if (image == null) {
                return Optional.empty();
            }
            writeJpeg(image, target.toFile());
            String url = uploadBaseUrl + "/covers/" + filename;
            log.info("[cover] 生成成功 pdf={} -> {}", pdfFile.getName(), url);
            return Optional.of(url);
        } catch (Exception e) {
            // 封面失败不影响教材本身，吞掉异常并清理半成品文件
            log.warn("[cover] 生成失败 pdf={} reason={}", pdfFile.getName(), e.getMessage());
            try {
                Files.deleteIfExists(target);
            } catch (IOException ignore) {
                // 清理失败无所谓
            }
            return Optional.empty();
        }
    }

    /**
     * 渲染 PDF 第一页为 RGB 图片
     *
     * @return 渲染成功返回图片；PDF 无页/加密/损坏返回 null
     */
    private BufferedImage renderFirstPage(File pdfFile) throws IOException {
        try (PDDocument doc = Loader.loadPDF(pdfFile)) {
            if (doc.isEncrypted()) {
                // 加密 PDF 尝试用空密码打开（多数"加密"实际是空口令的权限保护）
                try {
                    doc.setAllSecurityToBeRemoved(true);
                } catch (Exception e) {
                    log.warn("[cover] PDF 已加密且无法解密 {}", pdfFile.getName());
                    return null;
                }
            }
            int pages = doc.getNumberOfPages();
            if (pages <= 0) {
                log.warn("[cover] PDF 页数为 0 {}", pdfFile.getName());
                return null;
            }
            PDFRenderer renderer = new PDFRenderer(doc);
            return renderer.renderImageWithDPI(0, RENDER_DPI, ImageType.RGB);
        }
    }

    /**
     * 以指定质量写出 JPG（ImageIO 默认不压缩，必须手动设置压缩参数）
     */
    private void writeJpeg(BufferedImage image, File out) throws IOException {
        // JPG 不支持透明通道，确保是 RGB
        BufferedImage rgb = image.getType() == BufferedImage.TYPE_INT_RGB
                ? image
                : toRgb(image);
        ImageWriter writer = ImageIO.getImageWritersByFormatName("jpg").next();
        try (ImageOutputStream ios = ImageIO.createImageOutputStream(out)) {
            writer.setOutput(ios);
            ImageWriteParam param = writer.getDefaultWriteParam();
            param.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
            param.setCompressionQuality(JPEG_QUALITY);
            writer.write(null, new IIOImage(rgb, null, null), param);
        } finally {
            writer.dispose();
        }
    }

    private BufferedImage toRgb(BufferedImage src) {
        BufferedImage rgb = new BufferedImage(src.getWidth(), src.getHeight(), BufferedImage.TYPE_INT_RGB);
        rgb.getGraphics().drawImage(src, 0, 0, null);
        return rgb;
    }

    @Override
    public Optional<String> generateCoverForUrl(String fileUrl) {
        File pdf = resolveLocalFile(fileUrl);
        if (pdf == null) {
            log.debug("[cover] 按URL生成跳过：无法定位本地文件 fileUrl={}", fileUrl);
            return Optional.empty();
        }
        return generateCover(pdf);
    }

    @Override
    public int backfillAllMissingCovers() {
        List<Textbook> list = textbookMapper.selectList(new LambdaQueryWrapper<Textbook>()
                .isNull(Textbook::getCoverUrl)
                .isNotNull(Textbook::getFileUrl)
                .ne(Textbook::getFileUrl, ""));
        if (list.isEmpty()) {
            log.info("[cover] 回填跳过：无缺失封面的教材");
            return 0;
        }

        int success = 0;
        for (Textbook tb : list) {
            File pdf = resolveLocalFile(tb.getFileUrl());
            if (pdf == null) {
                log.warn("[cover] 回填跳过 id={} 无法定位本地文件 fileUrl={}", tb.getId(), tb.getFileUrl());
                continue;
            }
            Optional<String> cover = generateCover(pdf);
            if (cover.isEmpty()) {
                continue;
            }
            Textbook patch = new Textbook();
            patch.setId(tb.getId());
            patch.setCoverUrl(cover.get());
            textbookMapper.updateById(patch);
            success++;
        }
        log.info("[cover] 回填完成 total={} success={}", list.size(), success);
        return success;
    }

    /**
     * 把 fileUrl（/uploads/ebooks/xxx.pdf 或 http://host/uploads/ebooks/xxx.pdf）
     * 反解成本地磁盘文件
     *
     * @return 本地文件；无法解析或文件不存在返回 null
     */
    private File resolveLocalFile(String fileUrl) {
        if (fileUrl == null || fileUrl.isBlank()) {
            return null;
        }
        String path = fileUrl;
        // 绝对 URL：取 path 部分
        int schemeIdx = path.indexOf("://");
        if (schemeIdx > 0) {
            int slash = path.indexOf('/', schemeIdx + 3);
            path = slash > 0 ? path.substring(slash) : path;
        }
        // 去掉 uploadBaseUrl 前缀，得到 /ebooks/xxx.pdf
        if (path.startsWith(uploadBaseUrl)) {
            path = path.substring(uploadBaseUrl.length());
        }
        File f = Paths.get(uploadDir, path).toFile();
        return f.exists() && f.isFile() ? f : null;
    }
}

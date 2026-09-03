package com.zhiyu.service;

import java.io.File;
import java.util.Optional;

/**
 * 教材封面生成服务
 *
 * 教材上传的 PDF 默认没有封面图，导致学生端教材中心只能显示「书名首字」占位块。
 * 本服务在 PDF 落盘后用 PDFBox 渲染第一页为 JPG 缩略图，作为该教材的真实封面。
 */
public interface PdfCoverService {

    /**
     * 为本地 PDF 文件生成封面图
     *
     * @param pdfFile 已落盘的 PDF 文件
     * @return 封面图的可访问 URL（如 /uploads/covers/cover_xxx.jpg）；生成失败返回 empty
     */
    Optional<String> generateCover(File pdfFile);

    /**
     * 按教材的 fileUrl（如 /uploads/ebooks/xxx.pdf）定位本地 PDF 并生成封面
     *
     * @return 封面图的可访问 URL；文件不存在或生成失败返回 empty
     */
    Optional<String> generateCoverForUrl(String fileUrl);

    /**
     * 为已存在的教材批量生成封面并回填 cover_url
     *
     * @return 成功生成并回填的教材数量
     */
    int backfillAllMissingCovers();
}
